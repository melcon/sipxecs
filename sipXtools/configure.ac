AC_PREREQ(2.57)
AC_INIT(sipXtools, 16.02, sipx-dev@list.sipfoundry.org)
AC_CONFIG_AUX_DIR(config)
m4_include([config/general.m4])
m4_include([config/sipXlib.m4])
AM_INIT_AUTOMAKE(foreign tar-ustar)
SFAC_AUTOMAKE_VERSION([1.6])
AC_PROG_LIBTOOL
AC_PATH_PROG([BASH], [bash])
AC_PROG_CXX
AX_COMPILER_VENDOR
AC_PROG_CC
SFAC_INIT_FLAGS
SFAC_LIB_STACK
AC_CONFIG_FILES([
  Makefile
  src/Makefile
  src/syslog2siptrace/Makefile
])
AC_OUTPUT
