#!/usr/bin/env python
import pikepdf
import os

def is_pdf(file_path: str) -> bool:
    return os.path.splitext(file_path.lower())[1] == ".pdf"


def is_pdf_encrypted(file_path: str) -> bool:
    try:
        with pikepdf.open(file_path) as pdf:
            return pdf.is_encrypted
    except:
        return True


def pdf_has_attachments(file_path: str) -> bool:
    try:
        with pikepdf.open(file_path) as pdf:
            return len(pdf.attachments) > 0
    except:
        return False


def unlock_pdf(file_path: str):
    password = None
    for p in passwords:
        password = p.strip()
        try:
            with pikepdf.open(
                file_path, password=password, allow_overwriting_input=True
            ) as pdf:
                print("unlocked successfully")
                pdf.save(file_path)
                break
        except pikepdf.PasswordError:
            print("password is not working")
            continue
    if password is None:
        print("empty password file")


def extract_pdf_attachments(file_path: str):
    with pikepdf.open(file_path) as pdf:
        ats = pdf.attachments
        for atm in ats:
            # The name comes from the PDF itself: an absolute path or ../ would make
            # os.path.join write outside the consume directory, so keep only the basename
            trg_filename = os.path.basename(ats.get(atm).filename)
            if is_pdf(trg_filename):
                trg_file_path = os.path.join(consume_path, trg_filename)
                try:
                    with open(trg_file_path, "wb") as wb:
                        wb.write(ats.get(atm).obj["/EF"]["/F"].read_bytes())
                        print("saved: ", trg_file_path)
                except:
                    print("error ", trg_file_path)
                    continue
            else:
                print("skipped: ", trg_filename)

src_file_path = os.environ.get('DOCUMENT_WORKING_PATH')
consume_path = "/usr/src/paperless/consume/"

print("reading passwords")
passwords = os.environ.get('ENCRYPTED_FILE_PASSWORDS')
if not passwords:
    print("env variable ENCRYPTED_FILE_PASSWORDS is not defined")
    exit(1)
passwords = passwords.split(',')

if src_file_path is None:
    print("no file path")
    exit(0)

if not is_pdf(src_file_path):
    print("not pdf")
    exit(0)

if is_pdf_encrypted(src_file_path):
    print("decrypting pdf")
    unlock_pdf(src_file_path)
else:
    print("not encrypted")

if pdf_has_attachments(src_file_path):
    print("getting attachments")
    extract_pdf_attachments(src_file_path)
else:
    print("no attachments")