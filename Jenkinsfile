pipeline {
    agent any

    environment {
        APP_NAME = "seclock"

        // Change this to your actual AWS region
        AWS_REGION = "ap-south-1"

        ECR_REPOSITORY = "seclock"

        // Replace with your 12-digit AWS account ID
        AWS_ACCOUNT_ID = "123456789012"

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

            rm -rf venv

            python3.12 -m venv venv

            . venv/bin/activate

            python --version

            python -m pip install --upgrade pip

            pip install -r requirements.txt

            pip install --upgrade pytest httpx2

            echo "Checking installed packages..."

            pip show fastapi
            pip show starlette
            pip show httpx2
            pip show pytest
        '''
    }
}

        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate

                    echo "======================================"
                    echo "Running Python syntax checks"
                    echo "======================================"

                    python -m py_compile \
                        main.py \
                        crypto_engine.py \
                        ocr_engine.py \
                        audit_ledger.py

                    echo "Python syntax check passed."

                    echo "======================================"
                    echo "Running pytest"
                    echo "======================================"

                    if [ -f test_e2e.py ]; then

                        set +e

                        pytest -v test_e2e.py

                        TEST_EXIT_CODE=$?

                        set -e

                        if [ $TEST_EXIT_CODE -eq 5 ]; then

                            echo "WARNING: No pytest tests were collected."
                            echo "Continuing pipeline..."

                        elif [ $TEST_EXIT_CODE -ne 0 ]; then

                            echo "Tests failed with exit code $TEST_EXIT_CODE"

                            exit $TEST_EXIT_CODE

                        else

                            echo "All tests passed."

                        fi

                    else

                        echo "No test_e2e.py found."
                        echo "Skipping pytest."

                    fi
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        echo "======================================"
                        echo "Running SonarQube analysis"
                        echo "======================================"

                        sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName=${APP_NAME} \
                            -Dsonar.sources=. \
                            -Dsonar.python.version=3.12 \
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
                        echo "======================================"
                        echo "Building Docker image"
                        echo "======================================"

                        docker build \
                            -t ${IMAGE_NAME}:${IMAGE_TAG} \
                            -t ${IMAGE_NAME}:latest \
                            .

                        echo "Docker build completed."
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
                        echo "======================================"
                        echo "Logging in to Amazon ECR"
                        echo "======================================"

                        aws ecr get-login-password \
                            --region ${AWS_REGION} \
                        | docker login \
                            --username AWS \
                            --password-stdin ${ECR_REGISTRY}

                        echo "ECR login successful."
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Pushing Docker images to ECR"
                    echo "======================================"

                    docker push ${IMAGE_NAME}:${IMAGE_TAG}

                    docker push ${IMAGE_NAME}:latest

                    echo "Images pushed successfully."
                '''
            }
        }
    }

    post {

        success {
            echo "======================================"
            echo "Pipeline completed successfully!"
            echo "======================================"
            echo "Docker image:"
            echo "${IMAGE_NAME}:${IMAGE_TAG}"
        }

        failure {
            echo "======================================"
            echo "Pipeline failed!"
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

   
