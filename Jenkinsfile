# Test
pipeline {
    agent none

    stages {
        stage('Clusters') {

            steps {
                script {
                    openshift.withCluster( 'https://api.z1.orbx.uoldiveo.com', '6aOpWKdKP0snbh16yY84ntrpYr-JXZKQnCrMcyf2Ijo'  ) {
                        openshift.withProject( 'demo-ecommerce' ) {
                            echo "Hello from project ${openshift.project()} in cluster ${openshift.cluster()}"
                        }
                    }

                    openshift.withCluster( 'https://api.z2.orbx.uoldiveo.com', 'R_swrJ5DPN45mH0ng_7qT36YA1SbGjT4lBjf3D5SyuI' )  {
                        openshift.withProject( 'demo-ecommerce' ) {
                            echo "Hello from project ${openshift.project()} in cluster ${openshift.cluster()}"
                        }
                    }
                }
            }
        }
    }
}
