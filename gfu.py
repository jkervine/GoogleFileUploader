#!/usr/bin/python
'''
Google File Uploader
--------------------
This program is open source. Licenced under Apache Licence v2.0: http://www.apache.org/licenses/LICENSE-2.0.txt
@author: Juha Kervinen juha@apptomation.com
props to: Ryan Tucker, 2009/04/28 for the captcha solution
'''
import os.path
try:
    import gdata.docs.client
    import gdata.docs.data
    import gdata.data
    import gdata.client
except ImportError:
    print "You need to install Google Data API client for python. For more instructions, see http://joker.iki.fi/wp/googlefileuploader/"
    exit(1)

try:
    import argparse
except ImportError:
    print "Python v2.7 or greater required (for further instructions, see http://joker.iki.fi/wp/googlefileuploader/)."
    exit(1)

# Modify the following parameters to suit your system
# all of these are overridden from the command line
# ----
email_default = 'my.account@gmail.com'
password_default = 'my_p4ssw0rd'
file_on_disk_default = '/home/myaccount/backup.zip'
# -----
source = "GoogleFileUploader v.0.8"

parser = argparse.ArgumentParser(description="Google File Uploader")
parser.add_argument('-u', help='Username')
parser.add_argument('-p', help='Password (remember to escape special characters like !?$" etc.')
parser.add_argument('-fl', help='Local file with full path')
parser.add_argument('-fg', help='File on Google')

args = parser.parse_args();

if args.u is None: 
    email = email_default
else: 
    email = args.u
if args.p is None:
    password = password_default
else:
    password = args.p
if args.fl is None:
    file_on_disk = file_on_disk_default
else:
    file_on_disk = args.fl
if args.fg is None:
    file_on_google = os.path.basename(file_on_disk)
else:
    file_on_google = args.fg

client = gdata.docs.client.DocsClient(source=source)
client.http_client.debug = False
client.http_client.ssl = True
login = False

while login is False:
    try:
        login = True
        client.ClientLogin(email, password, source)
    except gdata.client.CaptchaChallenge as captcha:
        captcha_token = captcha.captcha_token
        captcha_url = captcha.captcha_url
        print "Need to complete captcha challenge at this URL: "+captcha_url
        captcha_response = raw_input("Please type the answer: ")
        try:
            client.ClientLogin(email,password,source,captcha_token=captcha_token,captcha_response=captcha_response)
            login = True
        except gdata.client.CaptchaChallenge:
            print "Captcha check failed."
            login = False
        except gdata.client.BadAuthentication:
            print "Wrong username or password."
            exit(1)
    except gdata.client.BadAuthentication:
        print "Wrong username or password."
        exit(1)
file_resource = gdata.docs.data.Resource(type = 'document', title=file_on_google)
filename = file_on_disk
try:
    open(filename)
except IOError:
    print "Cannot open "+filename+"."
    exit(1)
media = gdata.data.MediaSource()
media.set_file_handle(filename, 'application/octet-stream')
feedUri = '%s?convert=false' % gdata.docs.client.RESOURCE_UPLOAD_URI
file_resource = client.CreateResource(file_resource, create_uri = feedUri, media=media)
exit(0)
