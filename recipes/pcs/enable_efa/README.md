# Using EFA with AWS PCS

## Info

This recipe helps you implement the recommendations in [_Using Elastic Fabric Adapter (EFA) with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_networking_efa.html) in the AWS PCS user guide.

## Templates

This section contains CloudFormation templates for creating EFA-enabled resources. Follow the directions in the AWS PCS user guide to use them.

### Component Templates
* [`efa-sg.yaml`](assets/efa-sg.yaml) - Creates a self-referencing security group for EFA network interfaces.
* [`efa-placement-group.yaml`](assets/efa-placement-group.yaml) - Creates a cluster placement group for EFA-enabled instances.

### Launch Template Templates

#### `pcs-lt-efa.yaml` (General Purpose)
All-in-one template to create an EFA-enabled security group, placement group, and launch template for instances.
- **Supports:** 1, 2, or 4 network cards (configurable)
- **Use case:** General purpose for various instance types
- **Features:** Conditional logic to determine number of interfaces

#### `pcs-lt-efa-p5.yaml` (P5-Specific)
Optimized template specifically for P5 instances with configurable EFA network interfaces.
- **Supports:** 16 or 32 network interfaces (configurable)
- **Use case:** P5 instance family (p5.48xlarge, p5e.48xlarge, p5en.48xlarge)
- **Features:** Conditional logic based on instance type requirements

## P5 Template Details

The P5-specific template (`pcs-lt-efa-p5.yaml`) provides:

- **Configurable EFA-enabled network interfaces** (16 or 32 based on instance type)
- **Primary interface** (NetworkCardIndex 0, DeviceIndex 0) with SSH, Cluster, and EFA security groups
- **Additional EFA interfaces** (NetworkCardIndex 1-15 or 1-31, DeviceIndex 1) with EFA security group only
- **Cluster placement group** support (auto-created or user-provided)
- **P5-optimized** security group naming and tagging

### Instance Type Support

| Instance Type | Network Interfaces | Parameter Value |
|---------------|-------------------|-----------------|
| p5.48xlarge   | 32                | `NetworkInterfaceCount=32` |
| p5e.48xlarge  | 32                | `NetworkInterfaceCount=32` |
| p5en.48xlarge | 16                | `NetworkInterfaceCount=16` |

### Network Interface Configuration

```yaml
# Primary interface (always present)
NetworkCardIndex: 0, DeviceIndex: 0
Security Groups: [EFA, Cluster, SSH]

# EFA interfaces 1-15 (always present)
NetworkCardIndex: 1-15, DeviceIndex: 1
Security Groups: [EFA]

# EFA interfaces 16-31 (only when NetworkInterfaceCount=32)
NetworkCardIndex: 16-31, DeviceIndex: 1
Security Groups: [EFA]
```

## Usage Examples

### Deploy General Purpose Template (1-4 network cards)
```bash
aws cloudformation create-stack \
  --stack-name my-efa-template \
  --template-body file://assets/pcs-lt-efa.yaml \
  --parameters \
    ParameterKey=NumberOfNetworkCards,ParameterValue=4 \
    ParameterKey=LaunchTemplateName,ParameterValue=my-nodegroup-efa \
    ParameterKey=VpcId,ParameterValue=vpc-12345678 \
    ParameterKey=NodeGroupSubnetId,ParameterValue=subnet-12345678 \
    ParameterKey=ClusterSecurityGroupId,ParameterValue=sg-12345678 \
    ParameterKey=SshSecurityGroupId,ParameterValue=sg-87654321 \
    ParameterKey=SshKeyName,ParameterValue=my-key-pair \
  --capabilities CAPABILITY_IAM
```

### Deploy P5 Template (32 network interfaces for p5.48xlarge/p5e.48xlarge)
```bash
aws cloudformation create-stack \
  --stack-name my-p5-efa-template \
  --template-body file://assets/pcs-lt-efa-p5.yaml \
  --parameters \
    ParameterKey=NetworkInterfaceCount,ParameterValue=32 \
    ParameterKey=LaunchTemplateName,ParameterValue=my-p5-nodegroup-efa \
    ParameterKey=VpcId,ParameterValue=vpc-12345678 \
    ParameterKey=NodeGroupSubnetId,ParameterValue=subnet-12345678 \
    ParameterKey=ClusterSecurityGroupId,ParameterValue=sg-12345678 \
    ParameterKey=SshSecurityGroupId,ParameterValue=sg-87654321 \
    ParameterKey=SshKeyName,ParameterValue=my-key-pair \
  --capabilities CAPABILITY_IAM
```

### Deploy P5 Template (16 network interfaces for p5en.48xlarge)
```bash
aws cloudformation create-stack \
  --stack-name my-p5en-efa-template \
  --template-body file://assets/pcs-lt-efa-p5.yaml \
  --parameters \
    ParameterKey=NetworkInterfaceCount,ParameterValue=16 \
    ParameterKey=LaunchTemplateName,ParameterValue=my-p5en-nodegroup-efa \
    ParameterKey=VpcId,ParameterValue=vpc-12345678 \
    ParameterKey=NodeGroupSubnetId,ParameterValue=subnet-12345678 \
    ParameterKey=ClusterSecurityGroupId,ParameterValue=sg-12345678 \
    ParameterKey=SshSecurityGroupId,ParameterValue=sg-87654321 \
    ParameterKey=SshKeyName,ParameterValue=my-key-pair \
  --capabilities CAPABILITY_IAM
```

## Template Comparison

| Feature | General Template | P5 Template |
|---------|------------------|-------------|
| Network Cards | 1, 2, or 4 (configurable) | 16 or 32 (configurable) |
| Conditional Logic | Yes (CardCount conditions) | Yes (Use32Interfaces condition) |
| Template Complexity | Moderate | Moderate |
| Use Case | General purpose | P5 instance family only |
| Parameters | `NumberOfNetworkCards` | `NetworkInterfaceCount` |
| Security Group Name | `efa-${StackName}` | `efa-p5-${StackName}` |
| Instance Tags | `HPCRecipes: true` | `HPCRecipes: true`, `InstanceType: P5` |
| Instance Support | Various instance types | p5.48xlarge, p5e.48xlarge, p5en.48xlarge |

## Choosing the Right Template

- **Use `pcs-lt-efa.yaml`** for general workloads with 1-4 network cards on various instance types
- **Use `pcs-lt-efa-p5.yaml`** for P5 instances requiring high-performance EFA networking:
  - Set `NetworkInterfaceCount=32` for p5.48xlarge and p5e.48xlarge
  - Set `NetworkInterfaceCount=16` for p5en.48xlarge

Feel free to use or adapt these templates for your own clusters.
