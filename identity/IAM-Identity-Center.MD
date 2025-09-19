# IAM Identity Center

## Set up

1. Go to IAM Identity Center and click Enable in the region nearest you
2. Make a note of the SSO start URL
3. Create a group
   - Give it a name e.g. `Streaming`
   - Assign the accounts you want to grant access to in this case the `Streaming` account
   - Assign a permission set e.g. `AdministratorAccess`
4. Add a User assigning it to the `Streaming` group
5. Click from the user email and complete setting password MFA etc
6. Got to the terminal and configure:

```bash
❯ aws configure sso
SSO session name (Recommended): edo-laptop
SSO start URL [None]: https://d-9c6756adb3.awsapps.com/start
SSO region [None]: eu-west-2
SSO registration scopes [sso:account:access]:
Attempting to automatically open the SSO authorization page in your default browser.
# Login on browser
The only AWS account available to you is: 727361020121
Using the account ID 727361020121
The only role available to you is: AdministratorAccess
Using the role name "AdministratorAccess"
Default client Region [eu-west-2]:
CLI default output format (json if not specified) [json]:
Profile name [AdministratorAccess-727361020121]: streaming
To use this profile, specify the profile name using --profile, as shown:

aws sts get-caller-identity --profile streaming
```