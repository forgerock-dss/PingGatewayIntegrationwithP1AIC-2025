# Script to deploy a local PingGateway instance in Standalone mode to protect a Sample Application via CDSSO with PingOne Advanced Identity Cloud (P1AIC)

Written by Darinder S. Shokar - Ping Identity

Accompanying blog post: XXXX

# Pre-requisites
* This script is Linux derivative specific.
* Java 17 onwards must be installed.
* Copy the PingGateway Standalone binary ZIP file from [here](https://backstage.forgerock.com/downloads/browse/ig/featured) to the target PingGateway host.
* Copy the PingGateway Sample application JAR file from [here](https://backstage.forgerock.com/downloads/browse/ig/featured) to the target PingGateway host.
* Assuming DNS is not used, the hosts files both on the client machine running the browser and on the IG host must be updated to map the IG and Sample App FQDNs to the IG IP address. Note the Sample App is deployed on the same host as IG just with a different alias. If the PingGateway IP was 172.168.1.10 then the hosts file entry might look like this:
`172.168.1.10 pinggateway.test.com sample.test.com`
* P1AIC must be configured with a Gateway agent, set with the correct redirect URIs and a user setup for login.

# Description
This script will:
 * Check the PingGateway target host can connect to the remote P1AIC or PingAM instance. If not exit
 * Check if PingGateway is already installed. If so stop if already running and delete the instance directory
 * Deploy PingGateway in the target directory
 * Configure PingGateway ports and setup a keystore if HTTPS is selected
 * Deploy the PingGateway Sample Application
 * Configure routes to the PingGateway Sample App to protect it via CDSSO with P1AIC
  
# Execution

1. Create a test user in ForgeRock Identity Cloud:
 * Login to the ForgeRock Identity Cloud 
 * Select the appropriate realm on the top left dropdown
 * Select the Identities drop down on the left menu then select Manage
 * Hit the New alpha/bravo realm user button, complete the form and hit save.

2. Create a profile for PingGateway:
 * Click Gateways and Agents on the left menu
 * Hit the blue New Gateway/Agent, select Identity Gateway and finally Save Profile
 * Enter an ID (for example `pinggateway_agent_cdsso`). This maps to the `IG_AGENT_ID` parmameter in the script
 * Enter a password. This maps to the `IG_AGENT_SECRET` parameter in the script 
 * Hit Save
 * Enter the Redirect URLs. For just http enter `http://[FQDN and PORT of PingGateway HOST]/home/cdsso/redirect` for HTTPS enter `https://[FQDN and PORT of PingGateway HOST]/home/cdsso/redirect`, e.g. http://pinggateway.test.com:9000/home/cdsso/redirect and/or HTTPS https://pinggateway.test.com:9443/home/cdsso/redirect 
 * Hit Save

3. Modify the parameters from lines 11-30 in the `install_ping_gateway_P1AIC.sh` script to reflect your environment. 

4. Execute the script:

**NOTE - For P1AIC due to the need for samesite cookie support deploy in HTTPS mode**

```sh
Execute using ./install_ig_fidc.sh http|https. For example ./install_ping_gateway_P1AIC.sh https
```
5. On completion. Hit the following https://pinggateway.test.com:9443/home/cdsso if configured from P1AIC or http://ig.test.com:9000/home/cdsso for HTTP or standalone PingAM. If the ports were modified the script will output the correct URLs to use.

**NOTE - If you have already logged in to P1AIC as part of step 1 ensure you close the browser and start a fresh one or logout. Otherwise the following error will result:** 
```sh
#error_description=Resource%20Owner%20Session%20not%20valid&error=access_denied
```

6. When either of the above URLs are hit, the browser will redirect to P1AIC for authentication (use the test account configured in step 1). On successful authentication the browser will redirect back to PingGateway and render the Sample App page as below:

![picture](./images/Sample_App_Success_Page.png)

7. After install to stop/start PingGateway and the Sample app use:
* Stop - `./install_ping_gateway_P1AIC.sh stop`
* Start - `./install_ping_gateway_P1AIC.sh start`


8. The installation will deploy in what's known as Production Mode. To enable Development mode (to for example view the PingGateway Studio editor) and to learn more about each mode check out [this](https://docs.pingidentity.com/pinggateway/latest/configure/operating-modes.html) link. Hint - requires modification to admin.json. 


10. To remove the PingGateway and Sample installation, stop PingGateway and the Sample App using the steps above and delete the `$INSTALL_LOC` location

**To read more check out [this](https://docs.pingidentity.com/pinggateway/latest/aic/cdsso.html) link.**

# Error checking
The script will check the following:
* The PingGateway ZIP file is present on the target filesystem.
* The PingGateway Sample App JAR file is present on the target filesystem.
* The PingGateway host FQDN is reachable.
* The Sample App FQDN is reachable.
* The target host can connect out to the P1AIC tenant.


# Script Output
```sh
=== Environment check ===
Script bundle: /<PATH>/PingGatewayIntegrationwithP1AIC-2025/PingGatewayIntegrationwithP1AIC-main
Install dir:   /<PATH>/PingGatewayIntegrationwithP1AIC-2025/pingGatewayDeployment

This will:
 - Install PingGateway (https)
 - Deploy the sample app
 - Configure CDSSO route for P1AIC
 - Install into: /<PATH>/PingGatewayIntegrationwithP1AIC-2025/pingGatewayDeployment

Proceed?
Enter Y to continue: Y
Removing existing install: /<PATH>/PingGatewayIntegrationwithP1AIC-2025/pingGatewayDeployment
=== Deploying PingGateway ===
Bootstrap start/stop to initialise directories
Stopping processes by pattern: openig
=== Configuring PingGateway (https) ===
Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 90 days
	for: CN=pinggateway.test.com, O=Example Corp, C=Ping
Configured HTTPS on port 9443
=== Deploying Sample App ===
=== Configuring routes ===
=== Starting Sample App ===
=== Stopping Sample App ===
Stopping processes by pattern: PingGateway-sample-application-2025.11.1.jar
Sample: http://sample.test.com:9001/home
Log:    /<PATH>/PingGatewayIntegrationwithP1AIC-2025/pingGatewayDeployment/sample_app/console.log
=== Starting PingGateway ===
=== Stopping PingGateway ===
Log: /<PATH>/PingGatewayIntegrationwithP1AIC-2025/pingGatewayDeployment/identity-gateway-2025.11.1/ping_gateway_config/logs/console.out
Access: https://pinggateway.test.com:9443/home/cdsso
Done.
```