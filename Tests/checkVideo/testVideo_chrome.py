#!/usr/bin/python3

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.common.exceptions import NoSuchElementException
import time
import sys
import os

options = webdriver.ChromeOptions()
options.add_argument("--use-fake-ui-for-media-stream")
options.add_argument("--disable-infobars")
options.add_argument("--ignore-certificate-errors")
options.add_argument("--start-maximized")
options.add_argument("--use-fake-device-for-media-stream")

driver = webdriver.Chrome(chrome_options = options)

#########
## VARS
#########

demos_pass = os.getenv('DEMOS_PASS')
call_pass = os.getenv('CALL_PASS')

#########
## DEMOS
#########

print ('Testing Demos...')

sutURL = 'https://OPENVIDUAPP:' + demos_pass + '@demos.openvidu.io:4443'
driver.get(sutURL)

time.sleep(5)

try:

	elem = driver.find_element_by_id('test-btn')
	elem.send_keys(Keys.RETURN)

	time.sleep(2)

	elem = driver.find_element_by_id('mat-input-0')
	elem.send_keys('MY_SECRET')

	elem = driver.find_element_by_id('join-btn')
	elem.send_keys(Keys.RETURN)

	time.sleep(5)

	driver.save_screenshot('/workdir/demos.png')

	if 'Stream playing' in driver.page_source:
		print ('Video detected.')
		elem = driver.find_element_by_id('test-btn')
		elem.send_keys(Keys.RETURN)
		demos = 0
	else:
		print ('Alert: No video detected.')
		demos = 1

except NoSuchElementException:  
    demos = 1

#########
## CALL
#########

print ('Testing Call...')

sutURL = 'https://call.openvidu.io/inspector'
driver.get(sutURL)

time.sleep(5)

try:

	elem = driver.find_element_by_id('secret-input')
	elem.send_keys(call_pass)

	elem = driver.find_element_by_id('login-btn')
	elem.send_keys(Keys.RETURN)

	time.sleep(2)

	elem = driver.find_element_by_id('menu-test-btn')
	elem.send_keys(Keys.RETURN)

	time.sleep(2)

	elem = driver.find_element_by_id('test-btn')
	elem.send_keys(Keys.RETURN)

	time.sleep(5)

	driver.save_screenshot('/workdir/call.png')

	if 'Stream playing' in driver.page_source:
		print ('Video detected.')
		elem = driver.find_element_by_id('test-btn')
		elem.send_keys(Keys.RETURN)
		call = 0
	else:
		print ('Alert: No video detected.')
		call = 1

except NoSuchElementException:  
    call = 1

driver.quit()

if demos:
	print ('Demos is failing...')

if call:
	print ('Call is failing...')

if demos or call:
	sys.exit(1)
else:
	sys.exit(0)