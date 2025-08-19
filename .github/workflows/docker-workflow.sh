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
    docker:
        name: containerization
        permissions:
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
    