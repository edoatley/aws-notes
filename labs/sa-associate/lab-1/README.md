# Lab 1: Foundations - Secure Access with IAM (Easy)

## Objective
Implement least-privilege IAM setup using users, groups, and managed policies instead of the root account.

## Success Criteria
- Enable MFA on the root account.
- Create users `dev-user` and `readonly-user`.
- Create groups `Developers` and `Auditors`.
- Attach `AmazonS3FullAccess` and `AmazonEC2FullAccess` to `Developers`.
- Attach `ReadOnlyAccess` to `Auditors`.
- `readonly-user` can view S3 buckets but cannot create them.
- `dev-user` can create S3 buckets but cannot view the IAM dashboard.

## Services Involved
- AWS Identity and Access Management (IAM)

## Tips
- Apply policies to groups, not directly to users, for easier role changes.
- MFA on the root user is critical and must be configured manually.
- Differentiate IAM users, roles, and policies for exam scenarios.

## Solution
_Add your implementation notes, console steps, and any CLI/SDK commands here._


