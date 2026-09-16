pipeline {
    agent any

    environment {
        APP_NAME = "seclock"
        AWS_REGION = "ap-south-1"
        ECR_REPOSITORY = "seclock"
        AWS_ACCOUNT_ID = "994878981749"
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
        SONAR_PROJECT_KEY = "seclock"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }


stage('Install Dependencies') {
    steps {
        sh '''
            set -e

            echo "===== REMOVE OLD VIRTUAL ENVIRONMENT ====="
            rm -rf venv

            echo "===== CREATE VIRTUAL ENVIRONMENT ====="
            python3 -m venv venv

            echo "===== ACTIVATE VIRTUAL ENVIRONMENT ====="
            . venv/bin/activate

            echo "===== PYTHON VERSION ====="
            python --version
            which python

            echo "===== UPGRADE PIP ====="
            python -m pip install --upgrade pip

            echo "===== INSTALL REQUIREMENTS ====="
            python -m pip install -r requirements.txt

            echo "===== INSTALL TEST DEPENDENCIES ====="
            python -m pip install --upgrade pytest httpx2

            echo "===== VERIFY FASTAPI ====="
            python -m pip show fastapi

            echo "===== VERIFY STARLETTE ====="
            python -m pip show starlette

            echo "===== VERIFY HTTPX2 ====="
            python -m pip show httpx2

            echo "===== VERIFY TESTCLIENT ====="
            python -c "from fastapi.testclient import TestClient; print('TestClient import SUCCESS')"
        '''
    }
}
       stage('Test') {
    steps {
        sh '''
            set -e

            . venv/bin/activate

            echo "===== PYTHON VERSION ====="
            python --version

            echo "===== PYTHON LOCATION ====="
            which python

            echo "===== SYNTAX CHECK ====="

            python -m py_compile \
                main.py \
                crypto_engine.py \
                ocr_engine.py \
                audit_ledger.py

            echo "Python syntax check passed."

            echo "===== TESTCLIENT CHECK ====="

            python -c "from fastapi.testclient import TestClient; print('TestClient import SUCCESS')"

            echo "===== RUNNING PYTEST ====="

            if [ -f test_e2e.py ]; then
                python -m pytest -v test_e2e.py
            else
                echo "No test_e2e.py found. Skipping tests."
            fi
        '''
    }
}
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName=${APP_NAME} \
                            -Dsonar.sources=. \
                            -Dsonar.python.version=3.12 \
                            -Dsonar.exclusions="venv/*,_pycache_/,sample_certificates/*"
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    env.IMAGE_TAG = "${BUILD_NUMBER}"

                    sh """
                        docker build \
                            -t ${IMAGE_NAME}:${IMAGE_TAG} \
                            -t ${IMAGE_NAME}:latest \
                            .
                    """
                }
            }
        }

        stage('ECR Login') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-credentials']
                ]) {
                    sh '''
                        aws ecr get-login-password \
                            --region ${AWS_REGION} \
                        | docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Docker image pushed to: ${IMAGE_NAME}:${IMAGE_TAG}"
        }

        failure {
            echo "Pipeline failed. Check the Jenkins console output."
        }

        always {
            sh '''
                rm -rf venv || true
            '''
        }
    }
}
