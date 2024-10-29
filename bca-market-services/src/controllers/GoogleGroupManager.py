from google.oauth2 import service_account
from googleapiclient.discovery import build
from os import getenv

class GoogleGroupManager:
    def __init__(self, service_account_file, admin_email='bca@sbclab.net'):
        self.SCOPES = [
            'https://www.googleapis.com/auth/admin.directory.group',
            'https://www.googleapis.com/auth/admin.directory.group.member'
        ]
        
        # Initialize credentials with domain-wide delegation
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file, scopes=self.SCOPES)
        delegated_credentials = credentials.with_subject(admin_email)
        
        # Build the directory service once
        self.service = build('admin', 'directory_v1', credentials=delegated_credentials)

    def add_user_to_group(self, user_email, group_email):
        member_body = {
            "email": user_email,
            "role": "MEMBER"  # Options are "MEMBER", "OWNER", or "MANAGER"
        }
        try:
            self.service.members().insert(groupKey=group_email, body=member_body).execute()
            print(f"User {user_email} added to group {group_email} successfully.")
        except Exception as e:
            print(f"An error occurred while adding user: {e}")

    def remove_user_from_group(self, user_email, group_email):
        try:
            self.service.members().delete(groupKey=group_email, memberKey=user_email).execute()
            print(f"User {user_email} removed from group {group_email} successfully.")
        except Exception as e:
            print(f"An error occurred while removing user: {e}")


if __name__ == "__main__":
    user_email: string = "user_to_add@example.com"
    group_email: string = "cardano_mainnet@blockchain-analytics-392322.google.com"
    service_account_key_file_path: string = getenv('GOOGLE_CREDENTIALS_PATH','')
    group_manager = GoogleGroupManager(service_account_key_file_path)

    # Add a user to a group
    group_manager.add_user_to_group(user_email, group_email)

    # Remove a user from a group
    group_manager.remove_user_from_group(user_email, group_email)
