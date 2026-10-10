SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS lop (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  ma_lop  VARCHAR(20)  NOT NULL UNIQUE,
  ten_lop VARCHAR(100) NOT NULL
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS sinh_vien (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  ma_sv  VARCHAR(20)  NOT NULL UNIQUE,
  ho_ten VARCHAR(100) NOT NULL,
  email  VARCHAR(100) NOT NULL,
  lop_id INT NULL,
  FOREIGN KEY (lop_id) REFERENCES lop(id) ON DELETE SET NULL
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS diem (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  sinh_vien_id  INT NOT NULL,
  mon_hoc       VARCHAR(100) NOT NULL,
  diem          DECIMAL(4,2) NOT NULL,
  CHECK (diem BETWEEN 0 AND 10),
  FOREIGN KEY (sinh_vien_id) REFERENCES sinh_vien(id) ON DELETE CASCADE
) CHARACTER SET utf8mb4;

INSERT INTO lop (ma_lop, ten_lop) VALUES
('CNTT-K24', 'Công nghệ thông tin K24'),
('ATTT-K24', 'An toàn thông tin K24');

INSERT INTO sinh_vien (ma_sv, ho_ten, email, lop_id) VALUES
('SV001', 'Nguyễn Văn An',   'an@example.com',    1),
('SV002', 'Trần Thị Bình',   'binh@example.com',  1),
('SV003', 'Lê Hoàng Cường',  'cuong@example.com', 2);

INSERT INTO diem (sinh_vien_id, mon_hoc, diem) VALUES
(1, 'Cơ sở dữ liệu', 8.5),
(1, 'Mạng máy tính', 7.0),
(2, 'Cơ sở dữ liệu', 9.0),
(3, 'An toàn thông tin', 8.0);
