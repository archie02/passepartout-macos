#!/bin/sh
bundle exec fastlane --env secret-codesign,secret-deploy update_provisioning type:adhoc readonly:false
