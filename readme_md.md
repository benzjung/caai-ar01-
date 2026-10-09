# คอร์สแวร์รายวิชาโค้ดดิ้ง (ค 221012): พื้นฐานความจริงเสริม (AR) เพื่อการศึกษา 🎓

ระบบคอร์สแวร์ (CAI) ผ่านเว็บแอปพลิเคชัน สำหรับรายวิชาโค้ดดิ้ง (ค 221012) ระดับชั้นมัธยมศึกษาปีที่ 6 โรงเรียนบ้านครูเบ้น โดยมุ่งเน้นการสอนเรื่องเทคโนโลยีความจริงเสริม (Augmented Reality - AR) ระบบนี้ถูกออกแบบมาให้เป็น **Single Page Application (SPA)** ในไฟล์ HTML เดียว และทำงานร่วมกับ **Supabase** ในส่วนของระบบหลังบ้าน (BaaS)

## ✨ ฟีเจอร์หลัก (Features)

**สำหรับผู้เรียน (Students):**
* 🔐 เข้าสู่ระบบด้วยรหัสนักศึกษา 11 หลัก (ระบบสร้างบัญชีให้อัตโนมัติในครั้งแรก)
* 📊 แดชบอร์ดแสดงความก้าวหน้า ผลคะแนน (ก่อน/หลังเรียน) และ Normalized Gain
* 📱 เรียนรู้ผ่าน 5 หน่วยการเรียนรู้ พร้อมคำถามทบทวนความเข้าใจระหว่างเรียน
* 🕶️ สัมผัสประสบการณ์ WebAR โดยตรงผ่านเบราว์เซอร์ด้วย `<model-viewer>`
* 📤 ส่งงานปฏิบัติการ (ลิงก์/ไฟล์) และอัปโหลดรูปประจำตัว
* 📚 ดาวน์โหลดหรือเข้าถึงสื่อเพิ่มเติมจากผู้สอน

**สำหรับผู้สอน (Teachers):**
* 👥 ระบบจัดการผู้สอน (Teacher Dashboard)
* 📈 ดูสรุปผลการเรียนแบบ Real-time และส่งออกคะแนนเป็นไฟล์ CSV
* ✅ ตรวจงานปฏิบัติการ ให้คะแนน และพิมพ์ข้อเสนอแนะรายบุคคล
* 📁 จัดการสื่อการเรียนการสอน (อัปโหลด PDF, PPTX, DOCX หรือเพิ่มลิงก์/วิดีโอ)

## 🛠️ เครื่องมือและเทคโนโลยี (Tech Stack)

* **Frontend:** HTML5, Vanilla JavaScript, Tailwind CSS (ผ่าน CDN)
* **WebAR:** Google `<model-viewer>`
* **Backend / Database:** [Supabase](https://supabase.com/) (PostgreSQL, Authentication, Storage)
* **Security:** Row Level Security (RLS) อย่างเข้มงวด, Database Triggers ป้องกันการทุจริตคะแนน

## 🚀 คู่มือการติดตั้งและใช้งาน (Setup & Installation)

เนื่องจากระบบออกแบบมาให้ไม่ต้องใช้ Node.js หรือ Build tools การติดตั้งจึงสามารถทำได้ง่ายผ่าน Supabase Dashboard ดังนี้:

### 1. การเตรียมพร้อม Supabase
1. สมัครใช้งานและสร้าง Project ใหม่ที่ [Supabase](https://supabase.com/)
2. ไปที่เมนู **Authentication > Providers > Email**
3. ปิดการตั้งค่า **Confirm email** (Toggle off) แล้วกด Save เพื่อให้นักเรียนเข้าใช้งานได้ทันทีโดยไม่ต้องยืนยันอีเมล

### 2. การตั้งค่าฐานข้อมูล (Database Setup)
1. ไปที่เมนู **SQL Editor** ใน Supabase กด New Query
2. คัดลอกโค้ดทั้งหมดจากไฟล์ `setup.sql` ไปวาง
3. กด **RUN** เพื่อสร้างตาราง, ฟังก์ชัน, Triggers, RLS Policies และ Storage Buckets

### 3. การเชื่อมต่อ Frontend
1. ไปที่เมนู **Project Settings (รูปเฟือง) > API** ใน Supabase
2. คัดลอกค่า `Project URL` และ `anon public key`
3. เปิดไฟล์ `courseware.html` ด้วย Text Editor
4. ค้นหาและแทนที่ตัวแปรด้านล่าง (ประมาณบรรทัดที่ 40):
   ```javascript
   const SUPABASE_URL = 'ใส่_PROJECT_URL_ที่นี่';
   const SUPABASE_ANON_KEY = 'ใส่_ANON_KEY_ที่นี่';
   ```
5. บันทึกไฟล์ `courseware.html` และสามารถเปิดใช้งานผ่านเบราว์เซอร์ได้ทันที หรือนำไปโฮสต์บน GitHub Pages, Vercel, Netlify

### 4. การจัดการผู้ใช้งาน (User Management)
* **นำเข้ารายชื่อนักเรียน:** ไปที่ Table Editor > ตาราง `students` > กด Insert > Import data from CSV (โครงสร้าง: รหัส 11 หลัก, คำนำหน้า, ชื่อ, นามสกุล, ห้อง)
* **ตั้งสิทธิ์ผู้สอน:**
  1. เข้าหน้าเว็บ `courseware.html` ล็อกอินด้วยอีเมลของผู้สอน (เช่น `teacher@school.ac.th`)
  2. กลับไปที่ SQL Editor ใน Supabase รันคำสั่งนี้เพื่อตั้งค่าสิทธิ์ (เปลี่ยนอีเมลให้ตรงกัน):
     ```sql
     INSERT INTO public.teachers (user_id) 
     SELECT id FROM auth.users WHERE email = 'teacher@school.ac.th';
     ```

## 🔒 ความปลอดภัย (Security)
* มีการเปิด Row Level Security (RLS) ในทุกตาราง
* บัญชีผู้ใช้ถูกสร้างขึ้นได้เฉพาะเมื่ออีเมลตรงตามรูปแบบและมีรหัสนักศึกษาอยู่ในฐานข้อมูล (`handle_new_user` trigger)
* ผู้เรียนไม่สามารถแก้ไขคะแนนของตนเองในตาราง `submissions` ได้ (`protect_submission_evaluation` trigger)
* ไฟล์ใน Storage ป้องกันการเข้าถึงแบบสาธารณะ และอ่านได้ผ่าน Signed URL ที่กำหนดเวลาหมดอายุเท่านั้น

## 📄 โครงสร้างฐานข้อมูล (Schema)
* `teachers`: ข้อมูลผู้สอน
* `students`: รายชื่อและข้อมูลพื้นฐานของผู้เรียน
* `attempts`: การทำแบบทดสอบก่อน/หลังเรียน
* `progress`: ความก้าวหน้าการเรียนแต่ละหน่วย
* `submissions`: งานปฏิบัติการที่นักเรียนส่ง
* `materials`: สื่อการสอนเพิ่มเติมจากผู้สอน

---
*พัฒนาขึ้นเพื่อใช้ประกอบการเรียนการสอนรายวิชา ค 221012 โรงเรียนบ้านครูเบ้น*