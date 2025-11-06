// Jenkinsfile - Declarative pipeline
pipeline {
  agent any

  environment {
    // Default region and repo info
    AWS_REGION = "${env.AWS_REGION ?: 'ap-south-1'}"
    ECR_REPO = "${env.ECR_REPO ?: 'portfolio-web'}"
    IMAGE_TAG = "${env.BUILD_ID ?: 'latest'}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          echo "Building Docker image..."
          docker build -t ${ECR_REPO}:${IMAGE_TAG} .
        '''
      }
    }

    stage('Verify AWS Access') {
      steps {
        sh '''
          echo "Verifying AWS CLI and credentials..."
          aws --version
          aws sts get-caller-identity || { echo "❌ AWS credentials not found. Please verify Jenkins global credentials."; exit 1; }
        '''
      }
    }

    stage('ECR Login & Push Image') {
      steps {
        script {
          sh '''
            set -e
            echo "Setting AWS region: ${AWS_REGION}"
            aws configure set region ${AWS_REGION}

            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

            # Create repo if not exists
            if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
              echo "ECR repo ${ECR_REPO} not found. Creating..."
              aws ecr create-repository --repository-name "${ECR_REPO}" >/dev/null
            else
              echo "ECR repo exists."
            fi

            echo "Logging in to ECR..."
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

            echo "Tagging and pushing image..."
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}:latest

            docker push ${ECR_URI}:${IMAGE_TAG}
            docker push ${ECR_URI}:latest

            echo "✅ Successfully pushed images to ECR."
          '''
        }
      }
    }

    stage('Terraform Deploy') {
      // when {
      //   expression { return fileExists('infra') || fileExists('main.tf') }
      // }
      // steps {
      //   dir('infra') {
      //     sh '''
      //       set -e
      //       echo "Running Terraform..."
      //       terraform init -input=false
      //       terraform plan -out=tfplan -input=false
      //       terraform apply -input=false -auto-approve tfplan
      //     '''
      //   }
      // }
      steps {
        dir('terraform') {
          withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
            echo 'Initializing Terraform...'
            bat 'terraform init'
            bat 'terraform validate'
            bat 'terraform plan'
            bat 'terraform apply -auto-approve'
          }
        }
      }
    }
  }

  post {
    success {
      echo "✅ Pipeline completed successfully."
    }
    failure {
      echo "❌ Pipeline failed. Check the logs."
    }
  }
}
