aws ec2 create-launch-template-version \
  --launch-template-id TBD \
  --source-version '$Latest' \
  --launch-template-data "{\"UserData\":\"$(base64 -w 0 user_data.txt)\"}"