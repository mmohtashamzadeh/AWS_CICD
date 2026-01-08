pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  parameters {
    choice(name: 'ENV', choices: ['dev', 'prod'], description: 'Target environment')
    booleanParam(name: 'APPLY', defaultValue: false, description: 'Apply? (dev auto; prod requires APPLY=true + manual approval)')
  }

  environment {
    AWS_REGION = "eu-central-1"
    TF_IN_AUTOMATION = "true"
    AWS_EC2_METADATA_DISABLED = "true"   // prevent IMDS lookup delays on non-EC2 nodes
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

  stage('Who am I (AWS)') {
  steps {
    withCredentials([[
      $class: 'AmazonWebServicesCredentialsBinding',
      credentialsId: 'awscreds'
    ]]) {
      sh """
        set -e
        aws sts get-caller-identity
      """
    }
  }
}


    stage('Tooling sanity check') {
      steps {
        sh """
          set -e
          terraform version
          aws --version
          kubectl version --client
          helm version
          ansible --version
        """
      }
    }

    stage('Terraform fmt/validate/init') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              set -e
              terraform fmt -check -recursive
              terraform init -input=false
              terraform validate
            """
          }
        }
      }
    }

    stage('Terraform plan (PR)') {
      when { changeRequest() }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              set -e
              terraform init -input=false
              pwd
              ls -la
              ls -la terraform.tfvars
              terraform plan -var-file=terraform.tfvars -out=tfplan -input=false
              terraform show -no-color tfplan > plan.txt
            """
          }
        }
        archiveArtifacts artifacts: "terraform/envs/${params.ENV}/tfplan,terraform/envs/${params.ENV}/plan.txt", fingerprint: true
      }
    }

    stage('Terraform plan (Branch)') {
      when { not { changeRequest() } }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awscreds'
        ]]) {
          dir("terraform/envs/${params.ENV}") {
            sh """
              set -e
              pwd
              ls -la
              ls -la terraform.tfvars
              terraform init -input=false
              terraform plan -var-file=terraform.tfvars -out=tfplan -input=false
              terraform show -no-color tfplan > plan.txt
            """
          }
        }
        archiveArtifacts artifacts: "terraform/envs/${params.ENV}/tfplan,terraform/envs/${params.ENV}/plan.txt", fingerprint: true
      }
    }

    stage('Approval (prod only)') {
      when {
        allOf {
          not { changeRequest() }
          expression { params.ENV == 'prod' }
          expression { params.APPLY == true }
        }
      }
      steps {
        input message: "Apply changes to PROD?", ok: "Yes, apply"
      }
    }

    stage('Terraform apply') {
      when {
        allOf {
          not { changeRequest() }
          expression {
            // dev: auto-apply
            if (params.ENV == 'dev') return true
            // prod: only when APPLY=true (and approval stage will gate it)
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
              set -e
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
            set -e
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
        sh """
          set -e
          bash scripts/smoke_test.sh
        """
      }
    }
  }

  post {
    always {
      // Helpful debug context without leaking secrets
      sh """
        echo "=== Debug context ==="
        echo "ENV=${ENV}"
        echo "BRANCH_NAME=${BRANCH_NAME}"
        echo "CHANGE_ID=${CHANGE_ID}"
      """
    }
  }
}

