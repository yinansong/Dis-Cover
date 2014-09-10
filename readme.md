#Project Dis-Cover

##Overview
Dis-Cover is a platform for users to upload images and information of manhole covers in order to organize/sort them based on different characters and share them with other people interested in manhole covers.

##Technology Used
###Gems Used
* In All Environments: Sinatra(1.4.5), redis(3.1.0), httparty, rack.
* In Development Environment: Pry, Shotgun.
* In Test Environment: Rspec.
###APIs Used
* [Facebook](https://developers.facebook.com/)
* [Instagram](http://instagram.com/developer/).

##Instructions for Deployment
* Localhost
For Facebook login, make sure you have the `CLIENT_ID` and `APP_SECRET` set in the bash profile as `FB_CLIENT_ID` and `FB_APP_SECRET`.
* Heroku:
    - For Facebook login, make sure you have the `CLIENT_ID` and `APP_SECRET` set in the heroku variable section as `FB_CLIENT_ID` and `FB_APP_SECRET`.
    - Make sure to add Redistogo as an addon in the Heroku dashboard section.

##Test Suite
The test suite is still under development. Please come back to check soon.

##Author
This app is built by [Yinan Song](http://yinansong.com), with love for manhole covers.
