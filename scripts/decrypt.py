import os
import sys
import base64
import hashlib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding


class AesUtil:
    IV_LENGTH = 16  # 128-bit IV

    @staticmethod
    def derive_key(password: str) -> bytes:
        return hashlib.sha256(password.encode('utf-8')).digest()

    @staticmethod
    def encrypt(plain_text: str, password: str) -> str:
        key = AesUtil.derive_key(password)
        iv = os.urandom(AesUtil.IV_LENGTH)

        padder = padding.PKCS7(128).padder()
        padded_data = padder.update(plain_text.encode('utf-8')) + padder.finalize()

        cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
        encryptor = cipher.encryptor()
        cipher_text = encryptor.update(padded_data) + encryptor.finalize()

        combined = iv + cipher_text
        return base64.b64encode(combined).decode('utf-8')

    @staticmethod
    def decrypt(base64_cipher: str, password: str) -> str:
        key = AesUtil.derive_key(password)
        data = base64.b64decode(base64_cipher)

        iv = data[:AesUtil.IV_LENGTH]
        cipher_text = data[AesUtil.IV_LENGTH:]

        cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
        decryptor = cipher.decryptor()
        padded_plain = decryptor.update(cipher_text) + decryptor.finalize()

        unpadder = padding.PKCS7(128).unpadder()
        plain_data = unpadder.update(padded_plain) + unpadder.finalize()
        return plain_data.decode('utf-8')

def main():
    if len(sys.argv) != 3:
        print("Usage: python decrypt.py <file_path> <password>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    password = sys.argv[2]
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        if content.startswith('MMTENC:'):
            encrypted_content = content[7:]
            decrypted_content = AesUtil.decrypt(encrypted_content, password)
            base_name, extension = os.path.splitext(file_path)
            decrypted_file_path = f"{base_name}_decrypted{extension}"
            
            with open(decrypted_file_path, 'w') as f:
                f.write(decrypted_content)
                
            print(f"Decrypted content written to {decrypted_file_path}")
        else:
            print("The file does not appear to be encrypted.")
    
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
    except Exception as e:
        if isinstance(e, ValueError) and "Invalid padding bytes" in str(e):
            print("Error: Incorrect password or corrupted file.")
        else:
            print(f"An error occurred: {str(e)}")

if __name__ == "__main__":
    main()