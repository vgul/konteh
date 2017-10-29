# konteh.sh 
IP address extractor for internet provider company [http://www.telcom.net.ua/] ( http://www.telcom.net.ua/ )

How to run


  konteh.sh - IP address extractor for konteh.com.ua internet provider

  How to run

    konteh.sh [OPTIONS]

      --ip           - print only IP

      --[no-]dry-run - use cached data

      --help         - this help

      --config       - path to config file
            This file should contain variables

            KONTEH_LOGIN=pass
            KONTEH_PASSWD=pass

          Default path: /etc/konteh.conf

    Curl log files store in $(pwd)/Data directory
    or for root user in /var/cache/konteh/Data.
    They are rotate


Example

    $ konteh.sh
    Active:  Yes
    Status:  Connected
    Balance: 127,74 UAH
    To pay:  17,26 UAH
    Since:   2017-10-29 16:46:22 +0200
    IP:      178.210.154.33


Enjoy :)

See also [ukraine.sh] (https://github.com/vgul/ukraine.com.ua). Script for hosting company.


