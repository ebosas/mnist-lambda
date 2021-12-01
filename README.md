# MNIST Lambda

An application for handwritten digit recognition.

![](demo.png)

## Features

The application uses a pretrained deep learning model ([MNIST](https://github.com/onnx/models/tree/master/vision/classification/mnist)) to infer a digit from user input.

Created as a static S3 website, it uses a RESTful API at the backend implemented using AWS Lambda with Go runtime and API Gateway.

Deployed to AWS using Terraform. In addition to the backend functionality, it creates a CloudFront distribution and configures a domain with a TLS certificate.

The front end functionality is created using React/Typescript.

## Deploy

Prerequisites:

* A hosted zone in Route53
* An ACM certificate for your domain in `us-east-1`

Deploy the resources to AWS. Make sure to provide your own variables.

```bash
terraform apply \
    -var="aws_region=eu-west-1" \
    -var="domain_name=sub.example.com" \
    -var="hosted_zone=example.com"
```

Build the javascript file. Then upload the files from `web/static` to the created S3 bucket.

```bash
cd web/react
npm i
npm run build
```
