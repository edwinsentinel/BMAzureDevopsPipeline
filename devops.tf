# Provider Configuration
provider "azurdevops" {
  organization_url      = "https://dev.azure.com/BM-PROJECT"
  personal_access_token = "******"
}


# Pipeline Configuration
resource "azurdevops_pipeline" "BM-PROJECT" {
  name                = "BM-Project"
  project_id          = "BM-project"
  repository_id       = "https://github.com/edwinsentinel/BMAzureDevopsPipeline.git"
  repository_provider = "GitHub"



 # Stages
  stages {
    # Lint Stage
    stage {
      name  = "LintTestBM"
      depends_on = ["Checkout"]
      jobs {
        job {
          name   = "Lint"
          steps {
            #  linting step here
            step {
              task = "ShellScript"
              display_name = "Run Lint"
              inputs = {
                scriptPath = "$C:\\Users\\Sentinel\\Desktop\\BM\\lint.sh"
              }
              continue_on_error = false
              timeout_in_minutes = 5
            }
          }
        }
      }
      #  test for lint step
      test {
        command = "shellcheck --version"
        expected_return_code = 0
      }
    }
  # Unit Test Stage
    stage {
      name  = "Unit TestBM"
      depends_on = ["Lint"]
      jobs {
        job {
          name   = "Unit Test"
          steps {
            # unit testing step here
            step {
              task = "ShellScript"
              display_name = "Run Unit Tests"
              inputs = {
                scriptPath = "$C:\\Users\\Sentinel\\Desktop\\BM\\unit-tests.sh"
              }
              continue_on_error = false
              timeout_in_minutes = 10
            }
          }
        }
      }
      #  test for unit testing step
      test {
        command = "bash -c \"echo '2 + 2' | bc\""
        expected_output_regex = "4"
        expected_return_code = 0
      }
    }

 # SonarQube Stage
    stage {
      name  = "SonarQubeBM"
      depends_on = ["Unit Test"]
      jobs {
        job {
          name   = "SonarQubeBM"
          steps {
            #  SonarQube step here
            step {
              task = "SonarQubePrepare"
              inputs = {
                sonarqube_endpoint = "http://localhost:9000"
                projectKey = "BM-project"
                projectName = "BM-project"
                projectVersion = "v1"
                extraProperties = "sonar.login=$(sonar_login)"
              }
            }
            step {
              task = "SonarQubeAnalyze"
            }
            step {
              task = "SonarQubePublish"
              inputs = {
                pollingTimeoutSec = "300"
              }
            }
          }
        }
      }
      #  test for SonarQube step
      test {
        command = "sonar-scanner --version"
        expected_return_code = 0
      }
    }  


# Build Image Stage
    stage {
      name  = "Build Image"
      depends_on = ["SonarQube"]
      jobs {
        job {
          name   = "Build Image"
          steps {
            #  image building step here
            step {
              task = "Docker@22"
              inputs = {
                containerRegistry = "https://hub.docker.com"
                repository = "sentinelwawesh"
                command = "build"
                Dockerfile = "C:\\Users\\Sentinel\\Desktop\\BM\\spring-boot-docker-master\\spring-boot-app"
                arguments = "-t $(spring-boot-docker) ."
              }
            }
          }
        }
      }
      #  test for image building step
      test {
        command = "docker --version"
        expected_return_code = 0
      }
    }    
    
    
 # Push Image to Registry Stage
    stage {
      name  = "Push Image to DockerHub"
      depends_on = ["Build Image"]
      jobs {
        job {
          name   = "Push Image"
          steps {
            #  image pushing step here
            step {
              task = "Docker@23"
              inputs = {
                containerRegistry = "https://hub.docker.com"
                repository = "sentinelwawesh"
                command = "push"
                arguments = "$(spring-boot-docker)"
              }
            }
          }
        }
      }
      #  test for image pushing step
      test {
        command = "docker push dockerhub.com/sentinelwawesh:$(spring-boot-docker)"
        expected_return_code = 0
      }
    }


# Pull Image from Registry Stage
    stage {
      name  = "Pull Image from Dockerhub"
      depends_on = ["Push Image to Dockerhub"]
      jobs {
        job {
          name   = "Pull Image"
          steps {
            #  image pulling step here
            step {
              task = "Docker@2"
              inputs = {
                containerRegistry = "https://hub.docker.com"
                repository = "sentinelwawesh"
                command = "pull"
                arguments = "$(spring-boot-docker)"
              }
            }
          }
        }
      }
      #  test for image pulling step
      test {
        command = "docker image inspect  dockerhub.com/sentinelwawesh:$(spring-boot-docker)"
        expected_return_code = 0
      }
    }

  # Deploy to K8s Cluster Stage
    stage {
      name  = "Deploy to K8s Cluster"
      depends_on = ["Pull Image from DockerHub"]
      jobs {
        job {
          name   = "Deploy to K8s Cluster"
          steps {
            # deployment step here
            step {
              task = "Kubernetes@1"
              inputs = {
                kubernetesServiceConnection = "BM-Project"
                command = "apply"
                useConfigurationFile = "true"
                configurationType = "inline"
                inlineConfiguration = " dockerhub.com/sentinelwawesh:$(spring-boot-docker)"
                containerRegistryType = "Azure Container Registry"
                azureSubscriptionEndpoint = ""
                azureContainerRegistry = ""
                azureResourceGroup = "BM-PROJECT"
              }
            }
          }
        }
      }
      #  test for deployment step
      test {
        command = "kubectl get pods | grep spring-boot-docker"
        expected_return_code = 0
      }
    }

# Create Ingress Stage
stage {
  name = "Create Ingress"
  depends_on = ["Deploy to Kubernetes"]
  jobs {
    job {
      name = "Create Ingress"
      steps {
        #  ingress creation command step here
        step {
          task = "Kubernetes@1"
          inputs = {
            connectionType = "BM-Project"
            kubernetesServiceConnection = "BM-Project"
            namespace = "bmproject"
            command = "apply"
            arguments = "-f ingress.yaml"
            secretType = "kubectl"
            secretName = "bmproject"
            secretArguments = "-n bmproject"
          }
        }
      }
      #  test for ingress creation step
      test {
        command = "kubectl version"
        expected_return_code = 0
      }
    }
  }
}

# Deploy to Development Environment Stage
stage {
  name = "Deploy to Development Environment"
  depends_on = ["Create Ingress"]
  jobs {
    job {
      name = "Deploy to Development Environment"
      steps {
        #  deployment command step here
        step {
          task = "Kubernetes@1"
          inputs = {
            connectionType = "BM-Project"
            kubernetesServiceConnection = "MB-Project"
            namespace = "bmproject"
            command = "apply"
            arguments = "-f deployment-dev.yaml"
            secretType = "kubectl"
            secretName = "your-secret-name"
            secretArguments = "-n bmproject"
          }
        }
      }
      #  test for deployment to development environment step
      test {
        command = "kubectl get deployments"
        expected_return_code = 0
      }
    }
  }
}

# Deploy to Production Environment Stage
stage {
  name = "Deploy to Production Environment"
  depends_on = ["Create Ingress"]
  jobs {
    job {
      name = "Deploy to Production Environment"
      steps {
        #  deployment command step here
        step {
          task = "Kubernetes@1"
          inputs = {
            connectionType = "BM-Project"
            kubernetesServiceConnection = "MB-Project"
            namespace = "bmproject"
            command = "apply"
            arguments = "-f deployment-dev.yaml"
            secretType = "kubectl"
            secretName = "your-secret-name"
            secretArguments = "-n bmproject"
          }
        }
      }
      # test for deployment to production environment step
      test {
        command = "kubectl get deployments"
        expected_return_code = 0
      }
    }
  }
}
  }
}