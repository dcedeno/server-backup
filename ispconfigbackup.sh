#!/bin/bash
#
# ISPConfig3 back up script based on bak-res script by go0ogl3 gabi@eurosistems.ro 
# modified by DCV 
# Copyright (c) Ioannis Sannos ( http://www.isopensource.com )
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# The above copyright notice and this permission notice shall be included in
# all copies of the script.
#
# description: A backup script for sites and databases on ISPConfig 3 servers
# Add this script in cron tab in order to be executed once per day.
# Example (04:30 at night every day):
# 30 04 * * * /backup/ispc3backup.sh &> /dev/null
#
# author: Ioannis Sannos
# date: 2010-03-06 13:45:10
# The state of development is "It works for me"!
# So don't blame me if anything bad will happen to you or to your computer 
# if you use this script.
#

## Start user editable variables
CLIENTSDIR="/srv/www/clients" 		# directory where ICPConfig 3 clients folders are located
BACKUPDIR="/backup"					# backup directory
DBUSER="root"						 # database user
DBPASS="your_mysql_password_here"				# database password
TAR=`which tar`						# name and location of tar
ARG="-cjpSPf"		#sparse			# tar arguments P = removed / 
tmpdir="/tmp/tmpbck"				# temp dir for database dump and other stuff
## End user editable variables

########### make needed directories if not exist #############
if [ ! -d $BACKUPDIR/ ] ; then
	exit 0
fi
if [ ! -d $tmpdir/ ] ; then
	mkdir $tmpdir/
fi
if [ ! -d $BACKUPDIR/db/ ] ; then
	mkdir $BACKUPDIR/db/
fi
if [ ! -d $BACKUPDIR/db/daily/ ] ; then
	mkdir $BACKUPDIR/db/daily/
fi
if [ ! -d $BACKUPDIR/db/weekly/ ] ; then
	mkdir $BACKUPDIR/db/weekly/
fi
if [ ! -d $BACKUPDIR/webs/ ] ; then
	mkdir $BACKUPDIR/webs/
fi
if [ ! -d $BACKUPDIR/webs/daily/ ] ; then
	mkdir $BACKUPDIR/webs/daily/
fi
if [ ! -d $BACKUPDIR/webs/weekly/ ] ; then
	mkdir $BACKUPDIR/webs/weekly/
fi

FDATE=`date +%F`		# Full Date, YYYY-MM-DD, year sorted, eg. 2009-11-21
WDAY=`date +%w`			#Day of week (0 for sunday)

########### backup database #############

# check and fix any errors found
mysqlcheck -u$DBUSER -p$DBPASS --all-databases --optimize --auto-repair --silent 2>&1
# Starting database dumps
for i in `mysql -u$DBUSER -p$DBPASS -Bse 'show databases'`; do
	`mysqldump -u$DBUSER -p$DBPASS $i --allow-keywords --comments=false --add-drop-table > $tmpdir/db-$i-$FDATE.sql`
	# Daily backup and Weekly backup on sundays
	if [ $WDAY = "0" ] ; then
		if [ -f $BACKUPDIR/db/weekly/$i.tar.bz2 ] ; then
			rm -rf $BACKUPDIR/db/weekly/$i.tar.bz2
		fi
		if [ -f $BACKUPDIR/db/daily/$i.tar.bz2 ] ; then
			cp $BACKUPDIR/db/daily/$i.tar.bz2 $BACKUPDIR/db/weekly/$i.tar.bz2
			rm -rf $BACKUPDIR/db/daily/$i.tar.bz2
		fi
		$TAR $ARG $BACKUPDIR/db/daily/$i.tar.bz2 -C $tmpdir db-$i-$FDATE.sql

		if [ ! -f $BACKUPDIR/db/weekly/$i.tar.bz2 ] ; then
			cp $BACKUPDIR/db/daily/$i.tar.bz2 $BACKUPDIR/db/weekly/$i.tar.bz2
		fi
	else
		if [ -f $BACKUPDIR/db/daily/$i.tar.bz2 ] ; then
			rm -rf $BACKUPDIR/db/daily/$i.tar.bz2
		fi
		$TAR $ARG $BACKUPDIR/db/daily/$i.tar.bz2 -C $tmpdir db-$i-$FDATE.sql
	fi
	rm -rf $tmpdir/db-$i-$FDATE.sql
done
    
########### backup web sites #############

clientslist=`ls $CLIENTSDIR | grep ^client`
for client in $clientslist; do
	if [ -d $CLIENTSDIR/$client/ ] ; then
		webslist=`ls $CLIENTSDIR/$client/ | grep ^web`
		for web in $webslist; do
			if [ -d $CLIENTSDIR/$client/$web/ ] ; then
				cd $CLIENTSDIR/$client/$web/
				if [ $WDAY = "0" ] ; then
					if [ -f $BACKUPDIR/webs/weekly/$web.tar ] ; then
						rm -rf $BACKUPDIR/webs/weekly/$web.tar
					fi
					if [ -f $BACKUPDIR/webs/daily/$web.tar ] ; then
						cp $BACKUPDIR/webs/daily/$web.tar $BACKUPDIR/webs/weekly/$web.tar
						rm -rf $BACKUPDIR/webs/daily/$web.tar
					fi

					tar -cpf $BACKUPDIR/webs/daily/$web.tar .

					if [ ! -f $BACKUPDIR/webs/weekly/$web.tar ] ; then
						cp $BACKUPDIR/webs/daily/$web.tar $BACKUPDIR/webs/weekly/$web.tar
					fi
				else
					if [ -f $BACKUPDIR/webs/daily/$web.tar ] ; then
						rm -rf $BACKUPDIR/webs/daily/$web.tar
					fi
					tar -cpf $BACKUPDIR/webs/daily/$web.tar .
				fi
			fi
		done
	fi
done

# all done
exit 0
