#This command, starting from cat > example_parallelcluster.yaml << EOF and ending at EOF can be copy/paste into the CLI of a node with Parallelcluster installed. Ensure that you change the commented parameters to match your environment. 
cat > example_parallelcluster.yaml << EOF
Region: us-gov-west-1
Image:
  Os: alinux2
HeadNode:
  InstanceType: c5a.4xlarge
  Networking:
    #Edit the below line with your subnet id
    SubnetId: YOUR_SUBNET_ID
  Ssh:
    #Edit the below line with your SSH Key Name that will be used to login to the cluster
    KeyName: YOUR_SSH_KEYNAME
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws-us-gov:iam::aws:policy/AmazonSSMManagedInstanceCore
  Image:
      #Ensure that you put the resulting AMI ID here
      CustomAmi: YOUR_STIG'D_AMI
SharedStorage:
  - MountDir: /fsx  
    Name: FSxExtData
    StorageType: FsxLustre
    FsxLustreSettings:
      StorageCapacity: 1200
      DeploymentType: PERSISTENT_1
      PerUnitStorageThroughput: 50
      DeletionPolicy: Delete
  - MountDir: /ebs
    Name: EBSExtData
    StorageType: Ebs
    EbsSettings:
      VolumeType: io1
      DeletionPolicy: Delete
  - MountDir: /efs
    Name: EFSExtData
    StorageType: Efs
    EfsSettings:
      Encrypted: true
      EncryptionInTransit: true
      IamAuthorization: false
      PerformanceMode: maxIO
      ThroughputMode: provisioned
      ProvisionedThroughput: 512
      DeletionPolicy: Delete
Scheduling:
  Scheduler: slurm
  SlurmSettings:
    QueueUpdateStrategy: DRAIN
  SlurmQueues:
  - Name: queue1
    ComputeResources:
    - Name: compute
      Instances:
      - InstanceType: hpc6a.48xlarge
      MinCount: 1
      MaxCount: 10
      Efa:
       Enabled: true
    Networking:
      SubnetIds:
      #Edit the below line with your subnet id
      - YOUR_SUBNET_ID
      PlacementGroup:
        Enabled: true
    Iam:
      AdditionalIamPolicies:
       - Policy: arn:aws-us-gov:iam::aws:policy/AmazonSSMManagedInstanceCore
EOF


#Command to create the cluster
pcluster create-cluster --cluster-name example --cluster-configuration example_parallelcluster.yaml --suppress-validators type:AdditionalIamPolicyValidator