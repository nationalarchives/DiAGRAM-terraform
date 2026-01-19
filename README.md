## About

This repository contains the _infrastructure as code_ to support the 
[DiAGRAM application](https://diagram.nationalarchives.gov.uk).

DiAGRAM's _application code_ lives in a separate repository,
[here](https://github.com/nationalarchives/diagram).

## Structure of this repository

There is a root file which contains the Route53 hosted zone and the EventBridge API destination. 
All other resources are contained within the [site module](#the-site-module)

This is because we destroy and recreate the dev environment as part of the release process.
If we destroyed and recreated the hosted zone, the NS records would change and the delegation from TNA's root DNS would no longer work.
The eventbridge API destination is kept in case we want to send Slack messages during the release. 

### The site module

This contains the following resources
* The backend lambda
* An API Gateway API
* The Cloudfront distribution
* WAF & Shield protection for Cloudfront and Route53
* The S3 bucket which contains the static website files.

## Deploying the infrastructure

This is deployed using GitHub actions with the [apply workflow](./.github/workflows/apply.yml). 
The workflow gets temporary AWS credentials using the workflow token and `AssumeRoleWithWebIdentity`

### Environments & workspaces

The DiAGRAM application and its supporting infrastructure is deployed into
two separate environments: `live`, and `dev`. Each of these separate
environments corresponds to a separate AWS account. These separate environments
are managed with terraform workspaces.

You can then select an environment to work from with eg. 
`terraform workspace select dev`.

### Running locally

1. Clone DiAGRAM terraform project to local machine: https://github.com/nationalarchives/DiAGRAM-terraform and navigate to the directory

2. Switch to the Terraform workspace corresponding to the DiAGRAM environment to be worked on:

   ```
   [location of project] $ terraform workspace select live
   ```

3. Initialise Terraform (if not done so previously):

   ```
   [location of project] $ terraform init
   ```

4. To ensure the modules are up-to-date, run
   ```
   [location of project] $ terraform get -update
   ```

5. (Optional) To quickly validate the changes you made, run
   ```
   [location of project] $ terraform validate
   ```

6. Run Terraform to view changes that will be made to the DR2 environment AWS resources
    1. Make sure your credentials (for the environment that you are interested in) are valid/still valid first (the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN)
    2. If you have the AWS CLI installed:
        1. run `aws sso login --profile [account name where credentials are] && export AWS_PROFILE=[account name where credentials are]`
        2. run `aws sts assume-role --role-arn arn:aws:iam::[account number]:role/[terraform role] --role-session-name run-terraform`, which should return a JSON
        3. run `export AWS_ACCESS_KEY_ID=[paste value from JSON]`
        4. run `export AWS_SECRET_ACCESS_KEY=[paste value from JSON]`
        5. run `export AWS_SESSION_TOKEN=paste[paste value from JSON]`
    3. If the workspace has not been switched, run `terraform workspace select [workspace]`
        1. run `terraform workspace list` to see available workspaces and the current workspace
    4. Run
      ```
      [location of project] $ terraform plan
      ```

7. Run `terraform fmt --recursive` to properly format your Terraform changes before pushing to a branch.

### Troubleshooting:

1. If you get the message starting with `Failed to unlock state: failed to delete the lock file...`, ask the person in the
   `Who:` section (of the message) if it is alright to unlock the state, if it is, run `terraform force-unlock [ID]`.
2. If you are receiving an error message including the text "The security token included in the request is expired",
   either open up a new session or run this command `unset AWS_ACCESS_KEY_ID && unset AWS_SECRET_ACCESS_KEY && unset AWS_SESSION_TOKEN`
   in the same session and then setting these values again.


### Testing the deployment

After a successful deployment of the DiAGRAM application's infrastructure, the
DiAGRAM application should be accessible from: https://diagram.nationalarchives.gov.uk.

You should be able to `curl` the application's Lambda backend with:

```sh
curl -X POST "diagram.nationalarchives.gov.uk/api/test/is_alive"
```

If successful, this command should return the json `{"alive":true}`.

### DNS Routing

Each environment provides a Route53 provider. Amazon will provide four name
servers for each Route53 service (within each environment). These NS values are
provided to _The National Archives_ who will delegate the DNS for the two
domains to each Route53 service. For example, _TNA_ configure
`dev-diagram.nationalarchives.gov.uk` to pass DNS resolution to the 
managed Route53 via the four unique name server values. See `website/README.md` for current values.



