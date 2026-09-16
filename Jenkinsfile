pipeline {
    agent any

    environment {
        APP_NAME = "seclock"

        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT_ID = "994878981749"

        ECR_REPOSITORY = "seclock"
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

                    echo "======================================"
                    echo "REMOVE OLD VIRTUAL ENVIRONMENT"
                    echo "======================================"

                    rm -rf venv

                    echo "======================================"
                    echo "CREATE VIRTUAL ENVIRONMENT"
                    echo "======================================"

                    python3 -m venv venv

                    echo "======================================"
                    echo "ACTIVATE VIRTUAL ENVIRONMENT"
                    echo "======================================"

                    . venv/bin/activate

                    echo "Python version:"
                    python --version

                    echo "Python location:"
                    which python

                    echo "======================================"
                    echo "UPGRADE PIP"
                    echo "======================================"

                    python -m pip install --upgrade pip

                    echo "======================================"
                    echo "INSTALL REQUIREMENTS"
                    echo "======================================"

                    python -m pip install -r requirements.txt

                    echo "======================================"
                    echo "INSTALL TEST DEPENDENCIES"
                    echo "======================================"

                    python -m pip install --upgrade pytest httpx2

                    echo "======================================"
                    echo "VERIFY FASTAPI"
                    echo "======================================"

                    python -m pip show fastapi

                    echo "======================================"
                    echo "VERIFY STARLETTE"
                    echo "======================================"

                    python -m pip show starlette

                    echo "======================================"
                    echo "VERIFY HTTPX2"
                    echo "======================================"

                    python -m pip show httpx2

                    echo "======================================"
                    echo "VERIFY TESTCLIENT"
                    echo "======================================"

                    python -c "from fastapi.testclient import TestClient; print('TestClient import SUCCESS')"
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    set -e

                    . venv/bin/activate

                    echo "======================================"
                    echo "PYTHON VERSION"
                    echo "======================================"

                    python --version

                    echo "======================================"
                    echo "PYTHON LOCATION"
                    echo "======================================"

                    which python

                    echo "======================================"
                    echo "PYTHON SYNTAX CHECK"
                    echo "======================================"

                    python -m py_compile \
                        main.py \
                        crypto_engine.py \
                        ocr_engine.py \
                        audit_ledger.py

                    echo "Python syntax check PASSED."

                    echo "======================================"
                    echo "TESTCLIENT CHECK"
                    echo "======================================"

                    python -c "from fastapi.testclient import TestClient; print('TestClient import SUCCESS')"

                    echo "======================================"
                    echo "RUNNING PYTEST"
                    echo "======================================"

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
                            -Dsonar.python.version=3.14 \
                            -Dsonar.exclusions="venv/**,__pycache__/**,sample_certificates/**"
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
            echo "======================================"
            echo "PIPELINE COMPLETED SUCCESSFULLY"
            echo "======================================"

            echo "Docker image pushed to:"
            echo "${IMAGE_NAME}:${IMAGE_TAG}"
        }

        failure {
            echo "======================================"
            echo "PIPELINE FAILED"
            echo "======================================"

            echo "Check the Jenkins console output."
        }

        always {
            sh '''
                rm -rf venv || true
            '''
        }
    }
}
