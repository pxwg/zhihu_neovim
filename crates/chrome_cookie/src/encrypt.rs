use aes::Aes128;
use block_modes::block_padding::Pkcs7;
use block_modes::{BlockMode, Cbc};
use rand::RngCore;

type Aes128Cbc = Cbc<Aes128, Pkcs7>;

/// Encrypts plaintext using AES-128-CBC with PKCS7 padding.
///
/// # Arguments
/// * `key` - 16-byte encryption key
/// * `iv` - 16-byte initialization vector
/// * `plaintext` - data to encrypt
///
/// # Returns
/// Encrypted ciphertext as Vec<u8>
pub fn encrypt_aes128_cbc_pkcs7(key: &[u8; 16], iv: &[u8; 16], plaintext: &[u8]) -> Vec<u8> {
  let cipher = Aes128Cbc::new_from_slices(key, iv).expect("Invalid key or IV length");
  cipher.encrypt_vec(plaintext)
}

/// Generates a random 16-byte IV.
pub fn generate_random_iv() -> [u8; 16] {
  let mut iv = [0u8; 16];
  rand::thread_rng().fill_bytes(&mut iv);
  iv
}
