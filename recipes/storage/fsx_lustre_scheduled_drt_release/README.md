# Schedule a Recurring Data Repository Task to Auto-Release Data from FSx for Lustre DRAs

## Info

This recipe creates a EventBridge Scheduler that calls the FSx CreateDataRepositoryTask API to periodically release data that has been lazy-loaded into an FSx for Lustre Filesystem via Data Repository Associations (DRAs). This solution can be valuable to free capacity in the high-performance filesystem for hot data, while keeping the cooler data archived in S3. Anything that is released persists in the S3 DRA archive and can be re-loaded later.  

## Usage

This recipe assumes your FSx for Lustre filesystem already exists and that you have at least one DRA configured to map S3 data into the filesystem. 

### FSx for Lustre

FSx for Lustre DRTs can schedule release of data based on a [ReleaseConfiguration](https://docs.aws.amazon.com/fsx/latest/APIReference/API_ReleaseConfiguration.html). The ReleaseConfiguration defines the maximum tolerated number of DAYS since a file was last accessed. For example, if the configuration specifies 5 days, then data will be released on th 6th day after last access. 
e
1. Launch the [Cloudformation template for FSx for Lustre](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=autorelease-fsx&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_scheduled_drt_release/assets/autorelease_fsx.yaml)
2. Enter Required Parameters: 
    - FSxFileSystemId -- this is the ID of your FSx for Lustre Filesystem and begins with "fs-". 
    - DropDataOlderThanXDays -- this controls the expiration point for data. Remember: the unit is DAYS, and data expires the day AFTER this value. 
    - ReleasePaths -- selectively search for data to release from this comma-separated list of paths (e.g., "/s3, /s3archive, /other/path"). Note that entering `/` will traverse the entire filesystem (all DRAs) to find data to release. 
    - ReleaseSchedule -- a cron() pattern for the release schedule. 
3. Review details of your scheduled release cycle
    - [AWS EventBridge Schedules Console](https://console.aws.amazon.com/scheduler/home). If you click into the schedule it will show you a list of scheduled date/times when the task will execute.
    - [Amazon FSx for Lustre Filesystem Console](https://console.aws.amazon.com/fsx/home). After the schedule executes at least once, click into your filesystem and go to *Data repository* tab. The executed DRTs will appear under *Data Repository Tasks*, where you can click in for detail about how many files were released, which paths were searched, etc.
    - [AWS CloudTrail Events Console](https://console.aws.amazon.com/cloudtrailv2/home?#/events?ReadOnly=false). Any time the schedule executes the API calls will generate events in CloudTrail, whether the API call succeeds or fails. The details contained in CloudTrail Events can help you debug invalid API parameter values and other issues. 


## Cost Estimate
Cost for this recipe depends on two parts:
- Scheduled Events -- See [AWS EventBridge Scheduler Pricing](https://aws.amazon.com/eventbridge/pricing/). The AWS Free Tier for EventBridge scheduler allows 14,000,000 invocations per month, so it is unlikely but still possible for the scheduled API calls to add cost depending on your ReleaseSchedule. 
- FSx Data Repository Tasks -- Releasing capacity with DRTs has no cost. However, if released data is needed again later, standard charges associated with lazy-loading data through the Data Repository Association will apply. 
