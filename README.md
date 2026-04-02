<div id="top"></div>

# Dell iDRAC fan controller Docker image

## Table of contents
<ol>
  <li><a href="#features">Features</a></li>
  <li><a href="#container-console-log-example">Container console log example</a></li>
  <li><a href="#requirements">Requirements</a></li>
  <li><a href="#supported-architectures">Supported architectures</a></li>
  <li><a href="#download-docker-image">Download Docker image</a></li>
  <li><a href="#usage">Usage</a></li>
  <li><a href="#parameters">Parameters</a></li>
  <li><a href="#stepped-fan-control">Stepped Fan Control Explained</a></li>
  <li><a href="#troubleshooting">Troubleshooting</a></li>
  <li><a href="#contributing">Contributing</a></li>
  <li><a href="#license">License</a></li>
</ol>

<!-- FEATURES -->
## Features

This Docker container allows you to control Dell PowerEdge server fans via IPMI, replacing the default loud Dell fan control with a quieter custom profile.

### Core Features
- **Static fan speed control**: Set a fixed low fan speed for noise reduction
- **Stepped fan control**: Automatically adjusts fan speed based on CPU temperature in stepped increments
- **iDRAC reconnection**: Gracefully handles network interruptions without crashing
- **Third-party PCIe card support**: Optional control for non-Dell PCIe cards
- **Emergency fallback**: Automatically reverts to Dell default fan control if CPU overheats

### What's New (Fork Enhancements)
- **Stepped Fan Control**: Instead of incrementally increasing fan speed, the controller now calculates the target speed based on current temperature. When temperature decreases, fan speed automatically decreases to the appropriate step - no waiting for it to drop below threshold.
- **iDRAC Reconnection**: Network issues with iDRAC will no longer crash the container. The controller retries failed commands and continues operating when connectivity is restored.

<p align="right">(<a href="#top">back to top</a>)</p>

## Container console log example

![image](https://user-images.githubusercontent.com/37409593/216442212-d2ad7ff7-0d6f-443f-b8ac-c67b5f613b83.png)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- REQUIREMENTS -->
## Requirements
### iDRAC version

This Docker container only works on Dell PowerEdge servers that support IPMI commands, i.e. < iDRAC 9 firmware 3.30.30.30.

### To access iDRAC over LAN (not needed in "local" mode) :

1. Log into your iDRAC web console

![001](https://user-images.githubusercontent.com/37409593/210168273-7d760e47-143e-4a6e-aca7-45b483024139.png)

2. In the left side menu, expand "iDRAC settings", click "Network" then click "IPMI Settings" link at the top of the web page.

![002](https://user-images.githubusercontent.com/37409593/210168249-994f29cc-ac9e-4667-84f7-07f6d9a87522.png)

3. Check the "Enable IPMI over LAN" checkbox then click "Apply" button.

![003](https://user-images.githubusercontent.com/37409593/210168248-a68982c4-9fe7-40e7-8b2c-b3f06fbfee62.png)

4. Test access to IPMI over LAN running the following commands :
```bash
apt -y install ipmitool
ipmitool -I lanplus \
  -H <iDRAC IP address> \
  -U <iDRAC username> \
  -P <iDRAC password> \
  sdr elist all
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- SUPPORTED ARCHITECTURES -->
## Supported architectures

This Docker container is currently built and available for the following CPU architectures :
- AMD64
- ARM64

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- DOWNLOAD DOCKER IMAGE -->
## Download Docker image

- [Docker Hub](https://hub.docker.com/r/tigerblue77/dell_idrac_fan_controller)
- [GitHub Containers Repository](https://github.com/tigerblue77/Dell_iDRAC_fan_controller_Docker/pkgs/container/dell_idrac_fan_controller)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- USAGE -->
## Usage

### Quick Start

1. With local iDRAC:
```bash
docker run -d \
  --name Dell_iDRAC_fan_controller \
  --restart=unless-stopped \
  -e IDRAC_HOST=local \
  -e FAN_SPEED=10 \
  -e CPU_TEMPERATURE_THRESHOLD=60 \
  -e CPU_TEMPERATURE_THRESHOLD_MAX=80 \
  -e FAN_STEP=20 \
  -e CHECK_INTERVAL=30 \
  --device=/dev/ipmi0:/dev/ipmi0:rw \
  tigerblue77/dell_idrac_fan_controller:latest
```

2. With LAN iDRAC:
```bash
docker run -d \
  --name Dell_iDRAC_fan_controller \
  --restart=unless-stopped \
  -e IDRAC_HOST=<iDRAC IP address> \
  -e IDRAC_USERNAME=<iDRAC username> \
  -e IDRAC_PASSWORD=<iDRAC password> \
  -e FAN_SPEED=10 \
  -e CPU_TEMPERATURE_THRESHOLD=60 \
  -e CPU_TEMPERATURE_THRESHOLD_MAX=80 \
  -e FAN_STEP=20 \
  -e CHECK_INTERVAL=30 \
  tigerblue77/dell_idrac_fan_controller:latest
```

### Docker Compose Examples

#### Quiet Home Server (Recommended)
```yml
version: '3.8'

services:
  Dell_iDRAC_fan_controller:
    image: tigerblue77/dell_idrac_fan_controller:latest
    container_name: Dell_iDRAC_fan_controller
    restart: unless-stopped
    environment:
      - IDRAC_HOST=local
      - FAN_SPEED=10
      - CPU_TEMPERATURE_THRESHOLD=60
      - CPU_TEMPERATURE_THRESHOLD_MAX=80
      - FAN_STEP=5
      - CHECK_INTERVAL=30
      - IDRAC_RETRY_COUNT=3
      - IDRAC_RETRY_DELAY=5
    devices:
      - /dev/ipmi0:/dev/ipmi0:rw
```

#### Aggressive Cooling
```yml
version: '3.8'

services:
  Dell_iDRAC_fan_controller:
    image: tigerblue77/dell_idrac_fan_controller:latest
    container_name: Dell_iDRAC_fan_controller
    restart: unless-stopped
    environment:
      - IDRAC_HOST=<iDRAC IP address>
      - IDRAC_USERNAME=<iDRAC username>
      - IDRAC_PASSWORD=<iDRAC password>
      - FAN_SPEED=15
      - CPU_TEMPERATURE_THRESHOLD=55
      - CPU_TEMPERATURE_THRESHOLD_MAX=75
      - FAN_STEP=3
      - CHECK_INTERVAL=20
    devices:
      - /dev/ipmi0:/dev/ipmi0:rw
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- PARAMETERS -->
## Parameters

All parameters are optional as they have default values.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `IDRAC_HOST` | `local` | iDRAC connection: `local` or IP address |
| `IDRAC_USERNAME` | `root` | iDRAC username (for LAN connection) |
| `IDRAC_PASSWORD` | `calvin` | iDRAC password (for LAN connection) |
| `FAN_SPEED` | `10` | Base fan speed (%) when below temperature threshold |
| `CPU_TEMPERATURE_THRESHOLD` | `60` | Temperature (°C) to start stepped fan control |
| `CPU_TEMPERATURE_THRESHOLD_MAX` | `80` | Temperature (°C) to trigger emergency Dell default mode |
| `FAN_STEP` | `20` | Temperature step size (°C) for each fan speed increment |
| `CHECK_INTERVAL` | `30` | Seconds between temperature checks |
| `DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE` | `false` | Disable Dell cooling for third-party PCIe cards |
| `KEEP_THIRD_PARTY_PCIE_CARD_COOLING_RESPONSE_STATE_ON_EXIT` | `false` | Keep PCIe cooling state when container stops |
| `IDRAC_RETRY_COUNT` | `3` | Number of retries when iDRAC command fails |
| `IDRAC_RETRY_DELAY` | `5` | Seconds to wait between iDRAC retries |

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- STEPPED FAN CONTROL -->
## Stepped Fan Control Explained

### How It Works

Instead of incrementally increasing fan speed each cycle (which can cause overshoot), stepped control calculates the target speed based on the **current temperature**:

```
Temperature → Determine Step → Calculate Speed → Apply
```

### Speed Calculation

```
Speed = FAN_SPEED + (step_number × speed_per_step)

Where:
  step_number = floor((current_temp - THRESHOLD) / FAN_STEP)
  speed_per_step = (100 - FAN_SPEED) / max_steps
  max_steps = ceil((THRESHOLD_MAX - THRESHOLD) / FAN_STEP)
```

### Example

**Configuration:**
- `FAN_SPEED = 10`
- `FAN_STEP = 20`
- `CPU_TEMPERATURE_THRESHOLD = 60`
- `CPU_TEMPERATURE_THRESHOLD_MAX = 80`

**Result:**

| CPU Temperature | Fan Speed | Status |
|-----------------|-----------|--------|
| < 60°C | 10% | Quiet, base speed |
| 60-80°C | 10-100% | Stepped increase |
| >= 80°C | Dell Default | Emergency mode |

With `FAN_STEP=5` for finer control:

| CPU Temperature | Fan Speed |
|-----------------|-----------|
| < 60°C | 10% |
| 60-65°C | ~30% |
| 65-70°C | ~50% |
| 70-75°C | ~70% |
| 75-80°C | ~90% |
| >= 80°C | Dell Default |

### Configuration Guide

| Use Case | FAN_STEP | FAN_SPEED | Notes |
|----------|----------|-----------|-------|
| Silent home server | 5-10 | 5-10 | Smoother transitions, quieter |
| Default | 20 | 10 | Balanced |
| Performance | 3-5 | 15-20 | Faster response |

### Why Stepped Control?

**Problem with incremental control:**
- Temperature at 65°C → Fan 30%
- Temperature drops to 62°C → Fan still 30% (must stay below threshold to reset)
- Result: Unnecessarily high fan speed for longer

**Stepped control advantage:**
- Temperature at 70°C → Fan 50%
- Temperature drops to 67°C → Fan automatically drops to 30%
- No waiting for threshold - automatic adjustment

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- TROUBLESHOOTING -->
## Troubleshooting

### Your server frequently switches back to the default Dell fan mode:
1. Check `Tcase` (case temperature) of your CPU on Intel Ark website and then set `CPU_TEMPERATURE_THRESHOLD` to a slightly lower value. Example with my CPUs ([Intel Xeon E5-2630L v2](https://www.intel.com/content/www/us/en/products/sku/75791/intel-xeon-processor-e52630l-v2-15m-cache-2-40-ghz/specifications.html)) : Tcase = 63°C, I set `CPU_TEMPERATURE_THRESHOLD` to 60(°C).
2. If it's already good, adapt your `FAN_SPEED` value to increase the airflow and thus further decrease the temperature of your CPU(s)
3. If neither increasing the fan speed nor increasing the threshold solves your problem, then it may be time to replace your thermal paste

### You get `/!\ Your server isn't a Dell product. Exiting.` error on UnRAID OS

- Run the image using usual `docker run` command instead of UnRAID Community Apps or Docker UI. [More informations here.](https://github.com/tigerblue77/Dell_iDRAC_fan_controller_Docker/issues/89#issuecomment-4166458799)

### Container keeps retrying and logging warnings

This is expected behavior when the iDRAC is temporarily unreachable (network issues). The container will automatically resume normal operation when connectivity is restored. Adjust `IDRAC_RETRY_COUNT` and `IDRAC_RETRY_DELAY` if needed.

### Fan speed seems too high/too low

- For quieter operation: decrease `FAN_SPEED`, increase `FAN_STEP`
- For faster cooling response: increase `FAN_SPEED`, decrease `FAN_STEP`

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

To test locally, use either :
```bash
docker build -t tigerblue77/dell_idrac_fan_controller:dev .
docker run -d ...
```
or
```bash
export IDRAC_HOST=<iDRAC IP address>
export IDRAC_USERNAME=<iDRAC username>
export IDRAC_PASSWORD=<iDRAC password>
export FAN_SPEED=<decimal or hexadecimal fan speed>
export CPU_TEMPERATURE_THRESHOLD=<decimal temperature threshold>
export CPU_TEMPERATURE_THRESHOLD_MAX=<maximum temperature threshold>
export FAN_STEP=<temperature step size>
export CHECK_INTERVAL=<seconds between each check>
export IDRAC_RETRY_COUNT=<number of retries>
export IDRAC_RETRY_DELAY=<retry delay seconds>
export DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE=<true or false>
export KEEP_THIRD_PARTY_PCIE_CARD_COOLING_RESPONSE_STATE_ON_EXIT=<true or false>

chmod +x Dell_iDRAC_fan_controller.sh
./Dell_iDRAC_fan_controller.sh
```

### Running Tests
```bash
bats tests/
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- LICENSE -->
## License

Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa]. The full license description can be read [here][link-to-license-file].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg
[link-to-license-file]: ./LICENSE

<p align="right">(<a href="#top">back to top</a>)</p>
