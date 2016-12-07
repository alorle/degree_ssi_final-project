# UPNA | Security in Information Systems
## Project: Android devices security

__Authors:__ [Álvaro Orduna León](https://github.com/AlvaroOrduna) and [Jub3r](https://github.com/Jub3r).

__Description:__ Project for the subject Security in Information Systems imparted in the Degree of Computer Science from the Public University of Navarra (UPNA). It consists of a small script that allows you to embed a Metasploit Payload in an original APK file, so that you can take control of an Android device to perform security audits on mobile devices.

### Requirements

* lib32stdc++6
* lib32ncurses5
* lib32z1
* msfvenom (part of Metasploit Framework developed by [rapid7](https://github.com/rapid7/metasploit-framework))
* apktool (by [Connor Tumbleson](https://github.com/iBotPeaches/Apktool))
* jarsigner (part of JDK developed by [Oracle](http://www.oracle.com/technetwork/java/javase/overview/index.html))

### Usage

    main.sh <path_to_apk/file.apk> <payload_type> <LHOST> <LPORT>
    
_**NOTE:** The script will prompt you to modify some files throughout the process._

