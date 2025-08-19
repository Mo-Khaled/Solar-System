name: soalr system workflow

on:
    workflow_dispatch:
    push:
       branches:
            - feature-brancheA
            - main
      
env: 
    MONGO_URI: 'mongodb+srv://supercluster.d83jj.mongodb.net/superData'
    MONGO_USERNAME: ${{ vars.MONGO_USERNAME }}
    MONGO_PASSWORD: ${{ secrets.MONGO_PASSWORD }}


jobs:
    unit-testing:
        name: unit Testing
        strategy:
            matrix:
                nodejs_version: [18, 19, 20]
                os: [ubuntu-latest, macos-latest, windows-latest]

                exclude:
                    - nodejs_version: 18
                      os: macos-latest
        runs-on: ${{ matrix.os }}

        steps:
            - name: checkout Repo
              uses: actions/checkout@v5

            - name: Setup NodeJs version - ${{ matrix.nodejs_version }}
              uses: actions/setup-node@v4.4.0
              with:
                node-version: ${{ matrix.nodejs_version }}

            - name: Install dep
              run: npm install

            - name: unit testing
              id: NodeJs-unit-testing-step
              run: npm test

            - name: Archive test result
              if: steps.NodeJs-unit-testing-step.outcome == 'failure' || steps.NodeJs-unit-testing-step.outcome == 'success'
              uses: actions/upload-artifact@v4.6.2
              with:
                name: mocha-Test-Result-${{ matrix.nodejs_version }}-${{ matrix.os }}
                path: test-results.xml

    code-coverage:
        name: code coverage
        needs: unit-testing
        runs-on: ubuntu-latest
        steps:
            - name: checkout Repo
              uses: actions/checkout@v5

            - name: Setup NodeJs version - 18
              uses: actions/setup-node@v4.4.0
              with:
                node-version: 18
            
            - name: install depend.
              run: npm install


            - name: check code coverage
              continue-on-error: true
              run: npm run coverage

            - name: archive coverage results
              uses: actions/upload-artifact@v4.6.2
              with:
                name: code-coverage-Result
                path: coverage
                retention-days: 5

    docker:
        name: containerization
        needs: [code-coverage,unit-testing]
        permissions:
            contents: read
            packages: write
        runs-on: ubuntu-latest
        steps:
            - name: checkout
              uses: actions/checkout@v5

            - name: docker login
              uses: docker/login-action@v3.5.0
              with:
                username: ${{ vars.DOCKER_USERNAME }}
                password: ${{ secrets.DOCKER_PASSWORD }}


            - name: GHCR login
              uses: docker/login-action@v3.5.0
              with:
                registry: ghcr.io
                username: ${{github.repository_owner }}
                password: ${{ secrets.GITHUB_TOKEN }}

            - name: Build Docker file
              uses: docker/build-push-action@v6
              with:
               context: .
               push: false
               tags: ${{ vars.DOCKER_USERNAME }}/solar-system:latest

            - name: Test Docker image
              run: |
                docker images
                docker run --name solar-system-app -d \
                -p 3000:3000 \
                -e MONGO_URI=$MONGO_URI \
                -e MONGO_USERNAME=$MONGO_USERNAME \
                -e MONGO_PASSWORD=$MONGO_PASSWORD \
                ${{ vars.DOCKER_USERNAME }}/solar-system:latest
                export IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' solar-system-app)
                echo $IP

                echo Testing Image URL using wget
                wget -q -O - 127.0.0.1:3000/live | grep  live


            - name: Build Docker file
              uses: docker/build-push-action@v6
              with:
               context: .
               push: true
               tags: |
                ${{ vars.DOCKER_USERNAME }}/solar-system:latest
    terraform:
        name: terraform deployment
        needs: docker
        runs-on: ubuntu-latest
        environment: production
        steps:
            - name: checkout config files
              uses: actions/checkout@v5

            - name: Configure AWS Credentials
              uses: aws-actions/configure-aws-credentials@v4.3.1
              with:
                  aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
                  aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                  aws-region: us-west-2
       
            - name: HashiCorp - Setup Terraform
              uses: hashicorp/setup-terraform@v3.1.2
              with:
                 terraform_version: "1.1.7"

            - name: terraform init
              run: terraform init
              working-directory: ./Terraform


            - name: terraform plan
              run: terraform plan
              working-directory: ./Terraform

            - name: terraform apply or destroy
              run: |
                 if [ "${{ github.event.inputs.destroy }}" = "yes" ]; then
                 terraform destroy -auto-approve
                 else
                  terraform apply -auto-approve
                 fi
              working-directory: ./Terraform

    deploy:
        needs: terraform
        name: deploy to EKS
        runs-on: ubuntu-latest

        steps:
            - name: checkout config files
              uses: actions/checkout@v5


            - name: Configure AWS Credentials
              uses: aws-actions/configure-aws-credentials@v4.3.1
              with:
                  aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
                  aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                  aws-region: us-west-2

            - name: updat kubeconfig
              run: | 
                    aws eks --region us-west-2 update-kubeconfig --name stage-eks-cluster

            - name: Trigger app deployment
              uses: statsig-io/kubectl-via-eksctl@main
              env:
                 aws_access_key_id: ${{ secrets.AWS_ACCESS_KEY_ID }}
                 aws_secret_access_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                 region: us-west-2
                 cluster: stage-eks-cluster


            - name: Deploy k8s deployments
              run: |
               kubectl apply -f deployment.yml
               kubectl apply -f service.yml
              working-directory: ./kubernetes

            - name: Verify Deployment
              run: |
                kubectl get pods  
                kubectl get svc

            








            



    
