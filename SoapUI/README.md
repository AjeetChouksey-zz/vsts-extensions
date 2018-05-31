# VSTS Extension

SoapUI extension for VSTS

This extension can be used to run SoapUI script or to make SoapUI available for other tasks (as an environment variable).

[SoapUI](https://www.soapui.org/) version used is version 5.4

# Usage

- Go to VSTS Marketplace and install the extension
- In your build definition add the task "SoapUI"
  - Either select your project (and [arguments](https://www.soapui.org/test-automation/running-functional-tests.html))
    - If you add the argument -j (default value), this task will produce junit reports, which you can then send to VSTS/TFS using task "[Publish Test Results](https://docs.microsoft.com/en-us/vsts/build-release/tasks/test/publish-test-results)"
- or "SoapUI-Include"
  - This will create an environment variable called SOAPUI_EXE that you can use in the following tasks.


In both tasks, SoapUI will be downloaded the first time the task is called from https://ajeetgithub.blob.core.windows.net/soupui/SoapUI-5.4.0-windows-bin.zip
The next call will simply use the downloaded file without re downloading it.

For Hosted Agents, SoapUI will be downloaded each time the task is called.

# Additional jars (as part of package):	 
- POI.jar (Apache POI to generate consolidated report),
- jxl.jar (to fetch data at runtime from input xls) and
- SQLJDBC42.jar (to establish connection to Azure SQL DB for validations).

These jars doesn’t come as part of standard sopaui jars.

# Availability

This extension is publicly available on VSTS Marketplace: https://marketplace.visualstudio.com/items?itemName=AjeetChouksey.soapui#overview



The build number is automatically incremented on each commit by the VSTS Build task by a pattern like "0.0.$(Build.BuildId)". See https://www.visualstudio.com/en-us/docs/build/define/variables#predefined-variables for reference.

# Sample File:

You can use SOAPUI.xml
Download from https://github.com/AjeetChouksey/SoapUI/blob/master/SOAPUI.xml
# License

This extension is published under MIT license. See [license file](../blob/master/LICENSE).