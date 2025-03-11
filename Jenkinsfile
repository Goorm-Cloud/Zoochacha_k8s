pipeline {
    agent any
    
    options {
        timeout(time: 1, unit: 'HOURS')  // 빌드 타임아웃 설정
        disableConcurrentBuilds()  // 동시 빌드 방지
    }
    
    environment {
        SERVICE_NAME = 'admin-service'
        DOCKER_IMAGE_NAME = "${SERVICE_NAME}"
        AWS_ECR_REPO = "651706756261.dkr.ecr.ap-northeast-2.amazonaws.com/${SERVICE_NAME}"
        AWS_REGION = 'ap-northeast-2'
        DISCORD_WEBHOOK = credentials('jenkins-discord-webhook')
        GITHUB_CREDENTIALS = credentials('github-credentials')
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                cleanWs()  // clean() 대신 cleanWs() 사용
                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/Goorm-Cloud/zoochacha_admin.git'
            }
        }

        stage('Check Dependencies') {
            steps {
                script {
                    // 필요한 도구들이 설치되어 있는지 확인
                    sh '''
                        docker --version
                        aws --version
                    '''
                }
            }
        }

        stage('Configure AWS Credentials') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // AWS 인증 정보 설정
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh """
                            aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                            aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                            aws configure set region ${AWS_REGION}
                            aws configure set output json
                        """
                    }
                }
            }
        }

        stage('Get Secrets') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        // DB 시크릿 정보 가져오기
                        def dbSecret = sh(
                            script: """
                                aws secretsmanager get-secret-value \
                                    --secret-id ${SERVICE_NAME}/db \
                                    --region ${AWS_REGION} \
                                    --query SecretString \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        // 공통 시크릿 정보 가져오기
                        def commonSecret = sh(
                            script: """
                                aws secretsmanager get-secret-value \
                                    --secret-id ${SERVICE_NAME}/common \
                                    --region ${AWS_REGION} \
                                    --query SecretString \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        // 환경 변수로 설정
                        env.DB_SECRET = dbSecret
                        env.COMMON_SECRET = commonSecret
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Docker 이미지 빌드
                    docker.build("${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}", "--build-arg DB_SECRET='${env.DB_SECRET}' --build-arg COMMON_SECRET='${env.COMMON_SECRET}' .")
                }
            }
        }
        
        stage('Push to ECR') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_REPO}
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${AWS_ECR_REPO}:${BUILD_NUMBER}
                            docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${AWS_ECR_REPO}:latest
                            docker push ${AWS_ECR_REPO}:${BUILD_NUMBER}
                            docker push ${AWS_ECR_REPO}:latest
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            discordSend description: "[${SERVICE_NAME}] ✅ 빌드 성공 #${BUILD_NUMBER}\n브랜치: ${env.BRANCH_NAME}\n이미지 태그: ${BUILD_NUMBER}", 
                        title: "${SERVICE_NAME} 빌드 알림",
                        webhookURL: DISCORD_WEBHOOK
        }
        failure {
            discordSend description: "[${SERVICE_NAME}] ❌ 빌드 실패 #${BUILD_NUMBER}\n브랜치: ${env.BRANCH_NAME}\n실패 단계: ${currentBuild.result}", 
                        title: "${SERVICE_NAME} 빌드 알림",
                        webhookURL: DISCORD_WEBHOOK
        }
        always {
            script {
                // 로컬 Docker 이미지 정리
                sh """
                    docker rmi ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} || true
                    docker rmi ${AWS_ECR_REPO}:${BUILD_NUMBER} || true
                    docker rmi ${AWS_ECR_REPO}:latest || true
                """
            }
            // 작업 공간 정리
            cleanWs()
        }
    }
}