#!/usr/bin/env groovy

pipeline {
    agent any
    
    options {
        skipDefaultCheckout()
    }
    
    stages {
        stage('Checkout') {
            steps {
                sh 'echo "Started job \"$JOB_NAME [$BUILD_NUMBER]\". Check console output at $RUN_DISPLAY_URL" | slack-cli -d teknisk || true'
                deleteDir()
                checkout scm
            }
        }
        
        stage('Test') {
            steps {
                sh 'python3 -m unittest tests.testProdsys.py'
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: "test.log"
            archiveArtifacts artifacts: "target/**/log.txt"
            cleanWs()
        }
        
        failure {
            sh 'slack-cli -d teknisk -f test-result.txt || true'
            sh 'echo "Build failed: \"$JOB_NAME [$BUILD_NUMBER]\"" | slack-cli -d teknisk || true'
        }
        
        success {
            sh 'echo "Build successful: \"$JOB_NAME [$BUILD_NUMBER]\"" | slack-cli -d teknisk || true'
        }
    }
}
