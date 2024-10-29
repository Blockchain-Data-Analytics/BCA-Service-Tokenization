from google.oauth2 import service_account
from googleapiclient.discovery import build
from os import getenv

def add_user_to_group(user_email, group_email, service_account_key):

    SCOPES = [
        'https://www.googleapis.com/auth/admin.directory.group',
        'https://www.googleapis.com/auth/admin.directory.group.member'
    ]

    # Specify the admin user email to impersonate
    ADMIN_EMAIL = 'bca@sbclab.net'

    # Authenticate and build the Admin SDK directory service
    credentials = service_account.Credentials.from_service_account_file(
        service_account_key, scopes=SCOPES)
    delegated_credentials = credentials.with_subject(ADMIN_EMAIL)
    service = build('admin', 'directory_v1', credentials=delegated_credentials)

    member_body = {
        "email": user_email,
        "role": "MEMBER"
    }

    try:
        service.members().insert(groupKey=group_email, body=member_body).execute()
        print(f"User {user_email} added to group {group_email} successfully.")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    user_email: string = "user_to_add@example.com"  # The email from previous authentication
    group_email: string = "cardano_mainnet@blockchain-analytics-392322.google.com"
    service_account_key_file_path: string = getenv('GOOGLE_CREDENTIALS_PATH','')
    add_user_to_group(user_email, group_email, service_account_key_file_path)
