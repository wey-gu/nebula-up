source .env
docker build -t weygu/nebula-dashboard:$dashboard_version .
docker push weygu/nebula-dashboard:$dashboard_version