# BreatheEasy  
**Personal air quality monitor with real-time alerts and crowdsourced data**

## Inspiration  
The BreatheEasy project was inspired by my 11-year-old cousin William, who has lived with asthma for most of his life. For individuals like William, managing asthma means being extra cautious of their surroundings—especially the quality of the air they breathe. BreatheEasy aims to provide a reliable, real-time tool to help make life easier for those living with asthma or other respiratory conditions.

## What It Does  
Traditional air quality maps rely on data from widely spaced monitoring stations, which may not reflect real conditions at street level. BreatheEasy improves on this by using the user’s GPS location, accessed via Bluetooth from their mobile device, to generate a more accurate, location-based air quality map. Real-time data is collected using an ESP32 microcontroller and CCS811 air quality sensor. This user-generated data offers a finer, hyperlocal view of air quality conditions.

## How We Built It  
- **Hardware:** CCS811 air quality sensor connected to an ESP32 via I2C  
- **Firmware:** Programmed with PlatformIO to collect air quality data and transmit via Bluetooth  
- **Mobile/Web App:** Built using Flutter for real-time map display and user interaction  
- **Backend:** Firebase Authentication for secure user login

## Challenges We Ran Into  
- Maintaining stable Bluetooth connections between ESP32 and mobile devices  
- Sensor calibration for consistent and accurate readings  
- Handling real-time data updates in the Flutter app efficiently

## Accomplishments  
- Successfully integrated hardware with mobile software for real-time data display  
- Built a responsive, user-friendly interface in Flutter  
- Created a working prototype that supports personalized and crowdsourced air quality tracking

## What We Learned  
- Interfacing sensors with microcontrollers and transmitting data via Bluetooth  
- Developing cross-platform apps using Flutter  
- Real-time data handling and user authentication with Firebase  
- The importance of testing with real environmental data to validate results

## What's Next  
- Improve battery life and sensor accuracy  
- Enable multi-user support and data aggregation for a community-based AQI map  
- Add additional sensors for other pollutants and allergens  
- Integrate weather data for a more complete environmental profile

## Tech Stack  
- ESP32  
- CCS811 Air Quality Sensor  
- Flutter  
- Firebase Authentication  
- GitHub
