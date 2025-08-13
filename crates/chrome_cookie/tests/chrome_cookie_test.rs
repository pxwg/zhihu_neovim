use chrome_cookie::{
  decrypt_chrome_cookie_linux, decrypt_chrome_cookie_macos_legacy, derive_linux_key,
  encrypt::encrypt_aes128_cbc_pkcs7, encrypt::generate_random_iv,
};

#[cfg(test)]
mod tests_linux_derive {
  use chrome_cookie::derive_linux_key;

  struct KeyDerivationKnownAnswer {
    password: &'static str,
    answer: [u8; 16],
  }

  #[test]
  fn test_derive_linux_key() {
    // Known answers from PBKDF2-HMAC-SHA1 with 1 iteration and "saltysalt" as salt.
    // ref: [chromium](https://source.chromium.org/chromium/chromium/src/+/main:components/os_crypt/sync/os_crypt_linux.cc)
    let cases = [
      KeyDerivationKnownAnswer {
        password: "peanuts",
        answer: [
          0xfd, 0x62, 0x1f, 0xe5, 0xa2, 0xb4, 0x02, 0x53, 0x9d, 0xfa, 0x14, 0x7c, 0xa9, 0x27, 0x27,
          0x78,
        ],
      },
      KeyDerivationKnownAnswer {
        password: "",
        answer: [
          0xd0, 0xd0, 0xec, 0x9c, 0x7d, 0x77, 0xd4, 0x3a, 0xc5, 0x41, 0x87, 0xfa, 0x48, 0x18, 0xd1,
          0x7f,
        ],
      },
      KeyDerivationKnownAnswer {
        password: "zxqfb",
        answer: [
          0xb7, 0x56, 0x30, 0x74, 0x74, 0xb0, 0x0d, 0xa3, 0x55, 0xf7, 0x73, 0xf0, 0x2f, 0x86, 0x1a,
          0xe4,
        ],
      },
    ];

    for case in cases.iter() {
      let derived = derive_linux_key(case.password);
      assert_eq!(
        derived, case.answer,
        "Failed for password: {:?}",
        case.password
      );
    }
  }
}

#[cfg(test)]
mod tests_linux {
  use super::*;
  #[test]
  fn test_decrypt_chrome_cookie_linux_v10() {
    let password = "peanuts";
    let key = derive_linux_key(password);
    let iv = [b' '; 16];
    let plaintext = b"test chrome cookie v10";
    let ciphertext = encrypt_aes128_cbc_pkcs7(&key, &iv, plaintext);

    // v10 prefix
    let mut encrypted_value = b"v10".to_vec();
    encrypted_value.extend_from_slice(&ciphertext);

    let decrypted = decrypt_chrome_cookie_linux(&encrypted_value, password)
      .expect("Decryption failed")
      .expect("No value returned");
    assert_eq!(decrypted.as_bytes(), plaintext);
  }

  #[test]
  fn test_decrypt_chrome_cookie_linux_v11() {
    let password = "zxqfb";
    let key = derive_linux_key(password);
    let iv = [b' '; 16];
    let plaintext = b"test chrome cookie v11";
    let ciphertext = encrypt_aes128_cbc_pkcs7(&key, &iv, plaintext);

    // v11 prefix
    let mut encrypted_value = b"v11".to_vec();
    encrypted_value.extend_from_slice(&ciphertext);

    let decrypted = decrypt_chrome_cookie_linux(&encrypted_value, password)
      .expect("Decryption failed")
      .expect("No value returned");
    assert_eq!(decrypted.as_bytes(), plaintext);
  }
}

#[cfg(test)]
mod tests_mac {
  use super::*;
  use hmac::Hmac;
  use pbkdf2::pbkdf2;
  use sha1::Sha1;

  #[test]
  fn test_decrypt_chrome_cookie_macos_legacy_known_answer() {
    let plaintext = [
      0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e,
      0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
      0x1e, 0x1f,
    ];
    let password = "mock_password";
    let salt = b"saltysalt";
    let iterations = 1003;
    let mut key = [0u8; 16];
    pbkdf2::<Hmac<Sha1>>(password.as_bytes(), salt, iterations, &mut key);

    let iv = [b' '; 16];
    let ciphertext = encrypt_aes128_cbc_pkcs7(&key, &iv, &plaintext);

    // Prefix in MacOS is "v10"
    let mut encrypted_value = b"v10".to_vec();
    encrypted_value.extend_from_slice(&ciphertext);

    let decrypted = decrypt_chrome_cookie_macos_legacy(&encrypted_value, password)
      .expect("Decryption failed")
      .expect("No value returned");

    assert_eq!(decrypted.as_bytes(), &plaintext);
  }
}
