// Jenkinsfile - Declarative pipeline
pipeline {
  agent any

  environment {
    // Set default region and repo name. Can be overridden in Jenkins job or credentials
    AWS_REGION = "${env.AWS_REGION ?: 'us-east-1'}"
    ECR_REPO = "${env.ECR_REPO ?: 'portfolio'}"      // repo name in ECR
    IMAGE_TAG = "${env.BUILD_ID ?: 'latest'}"
    IMAGE_LATEST = "${env.AWS_ACCOUNT_ID ?: ''}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}:${IMAGE_TAG}"
    IMAGE_LATEST_ALIAS = "${env.AWS_ACCOUNT_ID ?: ''}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}:latest"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          sh '''
            echo "Building Docker image..."
            docker build -t ${ECR_REPO}:${IMAGE_TAG} .
          '''
        }
      }
    }

    stage('Prepare AWS Credentials') {
      steps {
        // Use Jenkins Credentials: add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY as 'aws-creds' (Username/Password) or use 'withCredentials' for env
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh '''
            echo "AWS credentials available in environment"
            aws --version || echo "aws cli not found - ensure aws cli is installed on the agent"
          '''
        }
      }
    }

    stage('ECR Login & Push Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -e
            echo "Setting AWS region: ${AWS_REGION}"
            aws configure set region ${AWS_REGION}

            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

            # Create repo if not exists (safe to run)
            if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
              echo "ECR repo ${ECR_REPO} not found. Creating..."
              aws ecr create-repository --repository-name "${ECR_REPO}" >/dev/null
            else
              echo "ECR repo exists."
            fi

            echo "Logging in to ECR..."
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

            # Tag and push
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:latest

            echo "Pushing images..."
            docker push ${ECR_URI}:${IMAGE_TAG}
            docker push ${ECR_URI}:latest

            echo "Pushed: ${ECR_URI}:${IMAGE_TAG} && ${ECR_URI}:latest"
          '''
        }
      }
    }

    stage('Terraform Deploy (optional)') {
      when {
        expression { return fileExists('infra') || fileExists('main.tf') } // only if terraform files present
      }
      steps {
        dir('infra') { // assumes terraform files in infra/ ; adjust if different
          withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh '''
              set -e
              export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
              export AWS_DEFAULT_REGION=${AWS_REGION}

              terraform init -input=false
              terraform plan -out=tfplan -input=false
              terraform apply -input=false -auto-approve tfplan
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline finished successfully."
    }
    failure {
      echo "Pipeline failed. Check the logs."
    }
  }
}
