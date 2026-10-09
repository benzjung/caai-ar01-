-- ==============================================================================
-- 1. การตั้งค่าความปลอดภัยเบื้องต้น (Revoke & Search Path)
-- ==============================================================================
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- ==============================================================================
-- 2. สร้างตารางข้อมูล
-- ==============================================================================

-- ตารางผู้สอน
CREATE TABLE public.teachers (
    user_id uuid REFERENCES auth.users(id) PRIMARY KEY,
    created_at timestamptz DEFAULT now()
);

-- ตารางรายชื่อและข้อมูลผู้เรียน
CREATE TABLE public.students (
    id varchar(11) PRIMARY KEY, -- รหัสนักศึกษา 11 หลัก
    title varchar(20) NOT NULL,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    section varchar(10) NOT NULL,
    user_id uuid REFERENCES auth.users(id) UNIQUE, -- ผูกกับ auth.users
    photo_path text,
    created_at timestamptz DEFAULT now()
);

-- ตารางการทำแบบทดสอบ (ก่อน/หลังเรียน)
CREATE TABLE public.attempts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    kind varchar(4) CHECK (kind IN ('pre', 'post')) NOT NULL,
    score integer NOT NULL,
    answers jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(user_id, kind) -- ทำได้ครั้งเดียว
);

-- ตารางความก้าวหน้าการเรียน
CREATE TABLE public.progress (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    unit integer NOT NULL CHECK (unit BETWEEN 1 AND 5),
    done boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    UNIQUE(user_id, unit)
);

-- ตารางการส่งงานปฏิบัติ
CREATE TABLE public.submissions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    unit integer NOT NULL,
    kind varchar(10) CHECK (kind IN ('link', 'file')) NOT NULL,
    url text,
    storage_path text,
    note text,
    score numeric(5,2),
    teacher_comment text,
    created_at timestamptz DEFAULT now()
);

-- ตารางสื่อของผู้สอน
CREATE TABLE public.materials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    title varchar(255) NOT NULL,
    kind varchar(10) CHECK (kind IN ('file', 'link', 'video')) NOT NULL,
    url text,
    storage_path text,
    file_name text,
    created_at timestamptz DEFAULT now()
);

-- ==============================================================================
-- 3. ฟังก์ชันและ Triggers
-- ==============================================================================

-- ฟังก์ชันตรวจสอบความเป็นผู้สอน (Security Definer เพื่อข้าม RLS บางส่วน)
CREATE OR REPLACE FUNCTION public.is_teacher() 
RETURNS boolean 
LANGUAGE sql 
SECURITY DEFINER 
SET search_path = public 
AS $$
  SELECT EXISTS (SELECT 1 FROM teachers WHERE user_id = auth.uid());
$$;

-- Trigger: ผูกบัญชีผู้ใช้ใหม่กับตารางนักเรียน และป้องกันคนนอก
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
AS $$
DECLARE
    v_student_id varchar(11);
BEGIN
    -- ตรวจสอบรูปแบบอีเมลนักเรียน (ตัวเลข 11 หลัก)
    IF NEW.email ~ '^[0-9]{11}@' THEN
        v_student_id := split_part(NEW.email, '@', 1);
        
        -- อัปเดต user_id ถ้ามีรายชื่ออยู่และยังไม่ถูกลงทะเบียน
        UPDATE public.students 
        SET user_id = NEW.id 
        WHERE id = v_student_id AND user_id IS NULL;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'รหัสนักศึกษา % ไม่ถูกต้อง หรือถูกลงทะเบียนไปแล้ว', v_student_id;
        END IF;
    END IF;
    -- หากไม่ใช่ตัวเลข 11 หลัก (เช่น ผู้สอน) ปล่อยผ่าน
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger: ป้องกันผู้เรียนแก้คะแนนและคอมเมนต์ใน submissions
CREATE OR REPLACE FUNCTION public.protect_submission_evaluation() 
RETURNS trigger 
LANGUAGE plpgsql
AS $$
BEGIN
    -- ถ้าไม่ใช่ผู้สอน ให้บังคับค่า score และ teacher_comment ให้เหมือนเดิม (ห้ามแก้)
    IF NOT public.is_teacher() THEN
        NEW.score = OLD.score;
        NEW.teacher_comment = OLD.teacher_comment;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_submission_protection
    BEFORE UPDATE ON public.submissions
    FOR EACH ROW EXECUTE FUNCTION public.protect_submission_evaluation();

-- ==============================================================================
-- 4. Row Level Security (RLS) Policies
-- ==============================================================================

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;

-- Teachers Table
CREATE POLICY "ผู้สอนมองเห็นตารางผู้สอน" ON public.teachers FOR SELECT TO authenticated USING (true);

-- Students Table
CREATE POLICY "นักเรียนเห็นข้อมูลตนเอง ผู้สอนเห็นทั้งหมด" ON public.students 
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());

-- นโยบายนี้ให้ผู้เรียนแก้ได้เฉพาะแถวตัวเอง ส่วนข้อจำกัดระดับคอลัมน์ใช้การเช็คใน USING
CREATE POLICY "นักเรียนแก้ไขรูปภาพตนเองได้ ผู้สอนแก้ไขทั้งหมดได้" ON public.students 
FOR UPDATE TO authenticated 
USING (user_id = auth.uid() OR public.is_teacher());

-- Attempts Table
CREATE POLICY "นักเรียนอ่าน/เพิ่ม ของตนเอง ผู้สอนอ่านทั้งหมด" ON public.attempts 
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY "นักเรียนเพิ่มข้อมูลตนเอง" ON public.attempts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- Progress Table
CREATE POLICY "นักเรียนอ่าน/เพิ่ม ของตนเอง ผู้สอนอ่านทั้งหมด" ON public.progress 
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY "นักเรียนเพิ่มข้อมูลความก้าวหน้า" ON public.progress FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "นักเรียนแก้ไขความก้าวหน้า" ON public.progress FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- Submissions Table
CREATE POLICY "นักเรียนอ่าน/เพิ่ม/แก้ งานตนเอง ผู้สอนทำได้ทั้งหมด" ON public.submissions 
FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_teacher());
CREATE POLICY "นักเรียนส่งงาน" ON public.submissions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "ผู้สอนแก้ไข(ให้คะแนน) หรือนักเรียนแก้งาน" ON public.submissions FOR UPDATE TO authenticated USING (user_id = auth.uid() OR public.is_teacher());

-- Materials Table
CREATE POLICY "ทุกคนอ่านสื่อได้" ON public.materials FOR SELECT TO authenticated USING (true);
CREATE POLICY "ผู้สอนจัดการสื่อได้" ON public.materials FOR ALL TO authenticated USING (public.is_teacher()) WITH CHECK (public.is_teacher());

-- ==============================================================================
-- 5. Views
-- ==============================================================================

-- สรุปผลสำหรับผู้สอน (Security Invoker)
CREATE OR REPLACE VIEW public.results WITH (security_invoker = true) AS
SELECT 
    s.id, s.title, s.first_name, s.last_name, s.section,
    s.photo_path,
    pre.score AS pre_score,
    post.score AS post_score,
    CASE 
        WHEN pre.score IS NOT NULL AND post.score IS NOT NULL THEN
            CASE WHEN pre.score = 10 THEN (CASE WHEN post.score = 10 THEN 1 ELSE 0 END)
            ELSE ROUND(((post.score - pre.score)::numeric / (10 - pre.score)::numeric), 2)
            END
        ELSE NULL
    END AS normalized_gain,
    (SELECT count(*) FROM public.progress p WHERE p.user_id = s.user_id) AS units_completed
FROM public.students s
LEFT JOIN public.attempts pre ON s.user_id = pre.user_id AND pre.kind = 'pre'
LEFT JOIN public.attempts post ON s.user_id = post.user_id AND post.kind = 'post'
ORDER BY s.id;

-- ==============================================================================
-- 6. Storage Buckets & Policies
-- ==============================================================================

-- ลบก่อนสร้าง (เพื่อความปลอดภัยในการรันซ้ำ) และสร้าง Buckets
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('photos', 'photos', false),
  ('submissions', 'submissions', false),
  ('materials', 'materials', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS Policies (Private, ควบคุมขนาดและประเภทผ่าน Storage API/Policy)
-- Photos
CREATE POLICY "นักเรียนจัดการรูปตัวเอง ผู้สอนอ่านได้" ON storage.objects
FOR ALL TO authenticated
USING (
  bucket_id = 'photos' AND 
  ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_teacher() )
);

-- Submissions (Files)
CREATE POLICY "นักเรียนจัดการไฟล์งานตัวเอง ผู้สอนอ่านได้" ON storage.objects
FOR ALL TO authenticated
USING (
  bucket_id = 'submissions' AND 
  ( (storage.foldername(name))[1] = auth.uid()::text OR public.is_teacher() )
);

-- Materials
CREATE POLICY "ทุกคนอ่านสื่อ ผู้สอนเขียนได้" ON storage.objects
FOR SELECT TO authenticated USING (bucket_id = 'materials');
CREATE POLICY "ผู้สอนจัดการสื่อ" ON storage.objects
FOR ALL TO authenticated USING (bucket_id = 'materials' AND public.is_teacher()) WITH CHECK (public.is_teacher());

-- ==============================================================================
-- 7. ข้อมูลจำลอง (นำเข้ารายชื่อจริงด้วย CSV ผ่าน Table Editor ในภายหลัง)
-- ==============================================================================
INSERT INTO public.students (id, title, first_name, last_name, section) VALUES
('66012345601', 'นาย', 'สมชาย', 'เรียนดี', '6/1'),
('66012345602', 'นางสาว', 'สมหญิง', 'ขยันยิ่ง', '6/1'),
('66012345603', 'นาย', 'มานะ', 'อดทน', '6/1'),
('66012345604', 'นางสาว', 'ปิติ', 'ยินดี', '6/2'),
('66012345605', 'นาย', 'ชูใจ', 'ใฝ่รู้', '6/2'),
('66012345606', 'นางสาว', 'วิภา', 'พัฒนา', '6/2')
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 8. การตั้งค่าผู้สอน (ยกเลิกคอมเมนต์บรรทัดล่างสุด เมื่อรันระบบแล้ว)
-- หมายเหตุ: ผู้สอนต้องสมัครสมาชิกในหน้าเว็บก่อน (ใช้อีเมลอะไรก็ได้ที่ไม่ขึ้นต้นด้วยเลข 11 หลัก) 
-- จากนั้นให้นำอีเมลนั้นมาใส่ด้านล่าง แล้วรันคำสั่งนี้
-- ==============================================================================

-- INSERT INTO public.teachers (user_id) 
-- SELECT id FROM auth.users WHERE email = 'teacher@school.ac.th';