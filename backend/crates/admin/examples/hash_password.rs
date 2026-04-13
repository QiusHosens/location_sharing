//! 生成默认管理员口令的 bcrypt 串：对明文做 MD5(hex)，再 bcrypt（与登录校验一致）
//! 运行: cargo run -p admin --example hash_password

use bcrypt::{hash, DEFAULT_COST};

fn main() {
    let md5_hex = "0192023a7bbd73250516f069df18b500"; // md5("admin123").hex()
    let h = hash(md5_hex, DEFAULT_COST).expect("bcrypt hash");
    println!("{}", h);
}
