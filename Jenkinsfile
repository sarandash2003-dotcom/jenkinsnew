pipeline {
    agent any

    environment {
        APP_NAME = "seclock"
        AWS_REGION = "ap-northeast-1"
        ECR_REPOSITORY = "seclock"
        AWS_ACCOUNT_ID = "699588736418"
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
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install pytest httpx2
                '''
            }
        }

        stage('Test') {
    steps {
        sh '''
            . venv/bin/activate

            echo "Running Python syntax checks..."

            python -m py_compile \
                main.py \
                crypto_engine.py \
                ocr_engine.py \
                audit_ledger.py

            echo "Running pytest..."

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
                echo "No test_e2e.py found. Skipping pytest."
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
