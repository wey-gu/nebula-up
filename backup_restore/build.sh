source .env
docker build -t weygu/nebula-br:$BR_VERSION .
docker push weygu/nebula-br:$BR_VERSION