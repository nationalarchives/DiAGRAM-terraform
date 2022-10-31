## About

This repository contains the _infrastructure as code_ to support the 
[DiAGRAM application](https://diagram.nationalarchives.gov.uk).

DiAGRAM's _application code_ lives in a separate repository,
[here](https://github.com/nationalarchives/diagram).

## Structure of this repository

The different infrastructure components required by the DiAGRAM application are
separated out into different modules. Briefly, they are comprised of:

- [`github-actions-user/`](/components/github-actions-user/): A module to define
  an IAM user, used by the DiAGRAM application's
  [GitHub Actions workflows](https://github.com/nationalarchives/DiAGRAM/tree/live/.github/workflows).

- [`container-registry/`](/components/container-registry/): A module to define
  a container registry, used to store [the custom Lambda container image](https://github.com/nationalarchives/DiAGRAM/blob/live/api/Dockerfile),
  used in the [DiAGRAM application's backend](https://github.com/nationalarchives/DiAGRAM/tree/live/api).

- [`lambda-api/`](/components/lambda-api/): A module to define a Lambda
  function, and API gateway integration, used to serve the DiAGRAM
  application's backend.

- [`website/`](/components/website/): A module to define an S3 bucket as a
  static website---used to host the 
  [DiAGRAM application's frontend](https://github.com/nationalarchives/DiAGRAM/tree/live/app)---and
  to define the content delivery network for the application's frontend and
  backend.

## Deploying the infrastructure

### Configuring secrets

To be able to deploy and test changes to the DiAGRAM application's
infrastructure, you will first need an AWS IAM user provisioned for you by The
National Archives (TNA).

You will then need to generate an access key and corresponding secret. You can
do so by logging into your TNA-provisioned AWS IAM, and navigating to
`Services` -> `Security, Identity, & Compliance` -> `IAM` -> `Users`. Once
here, locate and select your username in the displayed table, navigate to your
`Security credentials` tab, and select `Create access key`. Naturally, your
access key and its associated secret should be treated like a password, and
stored appropriately. You can read more about managing access keys 
[from AWS' own documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html).

Once you have your access key and corresponding secret, from within each
terraform module, create a file `secrets.auto.tfvars`, and populate it with the
following content:

```hcl
secrets = {
  tna_aws_access_key = "<YOUR-ACCESS-KEY-HERE>"
  tna_aws_secret_key = "<YOUR-SECRET-KEY-HERE>"
}
```

Replacing `<YOUR-ACCESS-KEY-HERE>` and `<YOUR-SECRET-KEY-HERE>` with your
access key and secret, as generated above.

Next, you will need to add the AWS account IDs of the three development
environments (`live`, `stage`, and `dev`) as provisioned by TNA, to the
`secrets.auto.tfvars` file. This file should then have the format:

```hcl
secrets = {
  tna_aws_access_key = "<YOUR-ACCESS-KEY-HERE>"
  tna_aws_secret_key = "<YOUR-SECRET-KEY-HERE>"
  service = {
    live = {
      account = "<LIVE-ENV-ACCOUNT-ID>"
    }
    stage = {
      account = "<STAGE-ENV-ACCOUNT-ID>"
    }
    dev = {
      account = "<DEV-ENV-ACCOUNT-ID>"
    }
  }
}
```

### Environments & workspaces

The DiAGRAM application and its supporting infrastructure is deployed into
three separate environments: `live`, `stage`, and `dev`. Each of these separate
environments corresponds to a separate AWS account. These separate environments
are managed with terraform workspaces.

You should create these workspaces from the root of each module with:

```shell
terraform init
for workspace in live stage dev;
do
  terraform workspace new $workspace;
done
```

You can then select an environment to work from with eg. 
`terraform workspace select dev`.

### Deployment

The infrastructure supporting the DiAGRAM application must be deployed in
stages. This is because the Lambda function serving the backend requests cannot
be created until a customer Lambda image has been pushed to AWS ECR. To deploy
the application, from scratch, the following steps must be followed:

0. Configure your AWS credentials, and the terraform workspaces, as detailed in
   the above sections.

1. `terraform apply` the
   [`github-actions-user/`](./components/github-actions-user/) module in each
   workspace.

2. For each workspace, view the access key and secret generated by the previous
   step (`terraform output gha_access_key_id`, and `terraform output gha_access_key_secret`),
   and add these values to _the corresponding environment_ in the 
   [application code's GitHub Environment secrets](https://github.com/nationalarchives/DiAGRAM/settings/environments).

   In other words, you should add the access key and secret generated from the
   `live` workspace to the GitHub `live` environment, the access key and secret
   generated from the `dev` workspace to the GitHub `dev`
   environment, and so on.

   The access key should be added as a secret named `AWS_ACCESS_KEY_ID`, and the
   secret should be added as a secret named `AWS_SECRET_ACCESS_KEY`.

3. `terraform apply` the
   [`container-registry/`](/components/container-registry/) module in each
   workspace.

4. Define the `ECR_REPO_NAME` secret for the `live`, `stage` and `dev`
   environments on GitHub, based on the `ecr_repo_name` terraform variable,
   and then trigger the CI job
   [`update-backend`](https://github.com/nationalarchives/DiAGRAM/blob/live/.github/workflows/update-backend.yml)
   from each GitHub environment. This will build and push the custom Lambda
   container image used by the backend to the container registry provisioned in
   the previous step.

5. `terraform apply` the [`lambda-api/`](/components/lambda-api/) module in
   each workspace. This will create a Lambda function, using the custom Lambda
   container image pushed in the previous step, and API Gateway integration.

6. Run `terraform apply -target module.tna_zones` and then `terraform apply`,
   for each workspace in the [`website/`](/components/website/) module.

7. Trigger the CI job [`update-frontend`](https://github.com/nationalarchives/DiAGRAM/blob/live/.github/workflows/update-backend.yml)
   from each GitHub environment. This will build the static site frontend, and
   upload it to the website's S3 bucket, as provisioned in the previous step.

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
servers for each R53 service (within each environment). These NS values are
provided to _The National Archives_ who will delegate the DNS for the three
domains to each R53 service. For example, _TNA_ configure
`staging-diagram.nationalarchives.gov.uk` to pass DNS resolution to the JR
managed R53 via the four unique name server values. See `website/README.md` for current values.

_The National Archives_ independently load a wildcard SSL certificate that can
be used by the other AWS web services but cannot be viewed by Jumping Rivers,
nor by any non-AWS services.


