pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'ENV', choices: ['dev', 'prod'], description: 'Target environment')
    booleanParam(name: 'APPLY', defaultValue: false, description: 'Apply? (dev auto; prod requires APPLY=true + approval)')
  }

  environment {
    AWS_REGION = "eu-central-1"
    TF_IN_AUTOMATION = "true"
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Tooling sanity check') {
      steps {
        sh """
          terraform version
          aws --version
          kubectl version --client
          helm version
          ansible --version
        """
      }
    }

    stage('Terraform fmt/validate') {
      steps {
        dir("terraform/envs/${params.ENV}") {
          sh """
            terraform fmt -check -recursive
            terraform init -input=false
            terraform validate
          """
        }
      }
    }

    stage('Terraform plan (PR only)') {
      when { changeRequest() }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              terraform init -input=false
              terraform plan -out=tfplan -input=false
              terraform show -no-color tfplan > plan.txt
            """
          }
        }
        archiveArtifacts artifacts: "terraform/envs/${params.ENV}/tfplan,terraform/envs/${params.ENV}/plan.txt", fingerprint: true
      }
    }

    stage('Terraform plan (branch)') {
      when { not { changeRequest() } }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              terraform init -input=false
              terraform plan -out=tfplan -input=false
              terraform show -no-color tfplan > plan.txt
            """
          }
        }
        archiveArtifacts artifacts: "terraform/envs/${params.ENV}/tfplan,terraform/envs/${params.ENV}/plan.txt", fingerprint: true
      }
    }

    stage('Approval (prod)') {
      when {
        allOf {
          not { changeRequest() }
          expression { params.ENV == 'prod' }
          expression { params.APPLY == true }
        }
      }
      steps {
        input message: "Apply to PROD? Confirm?", ok: "Yes, apply"
      }
    }

    stage('Terraform apply') {
      when {
        allOf {
          not { changeRequest() }
          expression {
            if (params.ENV == 'dev') return true
            return params.APPLY == true
          }
        }
      }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              terraform init -input=false
              terraform apply -input=false -auto-approve tfplan
              terraform output -json > tf_outputs.json
            """
          }
        }
        archiveArtifacts artifacts: "terraform/envs/${params.ENV}/tf_outputs.json", fingerprint: true
      }
    }

    stage('Post-provision (Ansible)') {
      when { not { changeRequest() } }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          sh """
            ansible-playbook -i localhost, -c local ansible/playbooks/10-bootstrap-cluster.yml -e env=${params.ENV} -e region=${env.AWS_REGION}
            ansible-playbook -i localhost, -c local ansible/playbooks/20-ns-cm-secret-rbac.yml -e env=${params.ENV}
            ansible-playbook -i localhost, -c local ansible/playbooks/30-calico-and-policies.yml -e env=${params.ENV}
            ansible-playbook -i localhost, -c local ansible/playbooks/40-deploy-app.yml -e env=${params.ENV}
          """
        }
      }
    }

    stage('Smoke test') {
      when { not { changeRequest() } }
      steps {
        sh "bash scripts/smoke_test.sh"
      }
    }
  }
}

