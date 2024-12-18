import boto3
import sys

# Function to check instance type availability in a region
def is_instance_type_available(region_name, instance_type):
    ec2 = boto3.client('ec2', region_name=region_name)
    try:
        # Use DescribeInstanceTypeOfferings API to check availability
        response = ec2.describe_instance_type_offerings(
            LocationType='region',
            Filters=[
                {'Name': 'instance-type', 'Values': [instance_type]},
            ]
        )
        return bool(response['InstanceTypeOfferings'])
    except Exception as e:
        print(f"Error checking region {region_name}: {e}")
        return False

# Function to get regions and check availability
def check_instance_availability(instance_type):
    ec2 = boto3.client('ec2')
    regions = [region['RegionName'] for region in ec2.describe_regions()['Regions']]
    
    availability = {}
    for region in regions:
        availability[region] = is_instance_type_available(region, instance_type)
    
    return availability

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <instance_type>")
        sys.exit(1)
    
    instance_type = sys.argv[1]
    print(f"Checking availability for instance type: {instance_type}\n")
    
    availability = check_instance_availability(instance_type)
    
    for region, is_available in availability.items():
        print(f"{region}: {'Available' if is_available else 'Not Available'}")
