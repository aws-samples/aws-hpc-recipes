# RES-Ready Image Builder Components

## Info

This recipe provides a library of EC2 Image Builder Components to help customers build [RES-Ready AMIs](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html) with pre-configured software stacks.

### Why Build RES-Ready AMIs?

Building custom RES-Ready AMIs is essential for providing efficient, scalable desktop environments to your end users:

- **Pre-configured Software Stacks**: Install and configure all required applications, libraries, and tools before users access their desktops. This eliminates manual setup time and ensures consistency across all user sessions.
- **Faster Session Launch Times**: With software pre-installed in the AMI, virtual desktops launch significantly faster. Users can start working immediately without waiting for software installation or configuration.
- **Standardization and Reproducibility**: Ensure all users have identical, tested environments. This reduces "works on my machine" issues and simplifies troubleshooting and support.
- **Cost Optimization**: Pre-baking software into AMIs reduces compute time needed for session initialization, lowering overall infrastructure costs. Users spend less time (and money) waiting for environments to be ready.
- **Security and Compliance**: Apply security patches, hardening configurations, and compliance requirements at the AMI level. This ensures all desktops meet organizational security standards from day one.
- **Custom Workflows**: Tailor desktop environments to specific research groups, projects, or use cases. Different teams can have AMIs optimized for their unique computational needs.
These components can be used individually or combined to create custom AMI recipes that meet your specific Research and Engineering Studio (RES) requirements.

## Usage

### Available Components

The components in this library are designed to be modular and reusable. Each component handles a specific dependency for your RES-Ready AMI (RES Software stack):

| Component Name | Description | Supported Operating Systems |
|----------------|-------------|----------------------------|
| [rstudio-linux](./assets/rstudio-linux.yml) | Installs RStudio Desktop | Amazon Linux 2023, Ubuntu 22/24, Rocky Linux 9 |

### Create Component - via AWS Console

Navigate to the EC2 Image Builder console in your AWS account
1. Create a new [Image Builder component](https://docs.aws.amazon.com/imagebuilder/latest/userguide/create-component.html)
2. **Component Name:** user friendly name of the component (e.g. `rstudio-linux`)
3. **Definition Document:** paste the contents of the component from this library
3. Select **Create component**

Refer to [Configure RES-ready AMIs](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html) for latest details on how to build your RES custom Software Stack.

### Create Component - via AWS CLI

You can also create and manage Image Builder components using the AWS CLI:

- Replace `COMPONENT_NAME` with the name of the component (e.g. `rstudio-linux`)

```bash
COMPONENT=<COMPONENT_NAME>
aws imagebuilder create-component \
  --name $COMPONENT \
  --semantic-version 1.0.0 \
  --platform Linux \
  --data file://assets/$COMPONENT.yml
```

This will return a component ARN that you can reference in your image recipes.

## Additional Resources

- [EC2 Image Builder Documentation](https://docs.aws.amazon.com/imagebuilder/)
- [RES Documentation](https://docs.aws.amazon.com/res/)
- [Building RES-Ready AMIs](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html)
