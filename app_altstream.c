/*
 * Asterisk -- An open source telephony toolkit.
 *
 * Copyright (C) 2019, Nadir Hamid
 * Copyright (C) 2005 - 2006, Digium, Inc.
 *
 * Mark Spencer <markster@digium.com>
 * Kevin P. Fleming <kpfleming@digium.com>
 *
 * Based on app_muxmon.c provided by
 * Anthony Minessale II <anthmct@yahoo.com>
 *
 * See http://www.asterisk.org for more information about
 * the Asterisk project. Please do not directly contact
 * any of the maintainers of this project for assistance;
 * the project provides a web site, mailing lists and IRC
 * channels for your use.
 *
 * This program is free software, distributed under the terms of
 * the GNU General Public License Version 2. See the LICENSE file
 * at the top of the source tree.
 */

/*! \file
 *
 * \brief AltStream() - Offload Asterisk audio processing to a Websocket server.
 * \ingroup applications
 *
 * \author Nadir Hamid <matrix.nad@gmail.com>
 *
 * \note Based on app_mixmonitor.c provided by
 * asterisk
 */

/*** MODULEINFO
	<use type="module">func_periodic_hook</use>
	<support_level>core</support_level>
 ***/

#ifndef AST_MODULE
#define AST_MODULE "Altstream"
#endif


#include "asterisk.h"

#include "asterisk/paths.h"     /* use ast_config_AST_MONITOR_DIR */
#include "asterisk/stringfields.h"
#include "asterisk/file.h"
#include "asterisk/audiohook.h"
#include "asterisk/pbx.h"
#include "asterisk/module.h"
#include "asterisk/cli.h"
#include "asterisk/app.h"
#include "asterisk/channel.h"
#include "asterisk/autochan.h"
#include "asterisk/manager.h"
#include "asterisk/callerid.h"
#include "asterisk/mod_format.h"
#include "asterisk/linkedlists.h"
#include "asterisk/test.h"
#include "asterisk/format_cache.h"
#include "asterisk/beep.h"

#include "asterisk/module.h"
#include "asterisk/astobj2.h"
#include "asterisk/pbx.h"
#include "asterisk/http_websocket.h"
#include "asterisk/tcptls.h"


/*** DOCUMENTATION
	<application name="AltStream" language="en_US">
		<synopsis>
			Forks a raw audio stream to a websocket server.
		</synopsis>
		<syntax>
			<parameter name="wsserver" required="true" argsep=".">
				<argument name="wsserver" required="true">
					<para>the URL to the  websocket server you want to send the audio to. </para>
				</argument>
				<argument name="extension" required="true" />
			</parameter>
			<parameter name="options">
				<optionlist>
					<option name="b">
						<para>Only save audio to the file while the channel is bridged.</para>
						<note><para>If you utilize this option inside a Local channel, you must make sure the Local
						channel is not optimized away. To do this, be sure to call your Local channel with the
						<literal>/n</literal> option. For example: Dial(Local/start@mycontext/n)</para></note>
					</option>
					<option name="B">
						<para>Play a periodic beep while this call is being recorded.</para>
						<argument name="interval"><para>Interval, in seconds. Default is 15.</para></argument>
					</option>
					<option name="v">
						<para>Adjust the <emphasis>heard</emphasis> volume by a factor of <replaceable>x</replaceable>
						(range <literal>-4</literal> to <literal>4</literal>)</para>
						<argument name="x" required="true" />
					</option>
					<option name="V">
						<para>Adjust the <emphasis>spoken</emphasis> volume by a factor
						of <replaceable>x</replaceable> (range <literal>-4</literal> to <literal>4</literal>)</para>
						<argument name="x" required="true" />
					</option>
					<option name="W">
						<para>Adjust both, <emphasis>heard and spoken</emphasis> volumes by a factor
						of <replaceable>x</replaceable> (range <literal>-4</literal> to <literal>4</literal>)</para>
						<argument name="x" required="true" />
					</option>
					<option name="r">
						<argument name="file" required="true" />
						<para>Use the specified file to record the <emphasis>receive</emphasis> audio feed.
						Like with the basic filename argument, if an absolute path isn't given, it will create
						the file in the configured monitoring directory.</para>
					</option>
					<option name="t">
						<argument name="file" required="true" />
						<para>Use the specified file to record the <emphasis>transmit</emphasis> audio feed.
						Like with the basic filename argument, if an absolute path isn't given, it will create
						the file in the configured monitoring directory.</para>
					</option>
					<option name="S">
						<para>When combined with the <replaceable>r</replaceable> or <replaceable>t</replaceable>
						option, inserts silence when necessary to maintain synchronization between the receive
						and transmit audio streams.</para>
					</option>
					<option name="i">
						<argument name="chanvar" required="true" />
						<para>Stores the AltStream's ID on this channel variable.</para>
					</option>
					<option name="p">
						<para>Play a beep on the channel that starts the recording.</para>
					</option>
					<option name="P">
						<para>Play a beep on the channel that stops the recording.</para>
					</option>
					<option name="D">
						<para>Direction of audiohook to process - supports in, out, and both</para>
					</option>
					<option name="T">
						<para>comma separated TLS config for secure websocket connections</para>
					</option>
					<option name="R">
						<para>Timeout for reconnections</para>
					</option>
					<option name="r">
						<para>Number of times to attempt reconnect before closing connections</para>
					</option>
				</optionlist>
			</parameter>
			<parameter name="command">
				<para>This is executed when the audio fork's hook finishes</para>
				<para>Any strings matching <literal>^{X}</literal> will be unescaped to <variable>X</variable>.</para>
				<para>All variables will be evaluated at the time AltStream is called.</para>
				<warning><para>Do not use untrusted strings such as <variable>CALLERID(num)</variable>
				or <variable>CALLERID(name)</variable> as part of the command parameters.  You
				risk a command injection attack executing arbitrary commands if the untrusted
				strings aren't filtered to remove dangerous characters.  See function
				<variable>FILTER()</variable>.</para></warning>
			</parameter>
		</syntax>
		<description>
			<para>Forks raw audio to a remote websocket.</para>
			<para>This application does not automatically answer and should be preceeded by
			an application such as Answer or Progress().</para>
			<note><para>AltStream runs as an audiohook.</para></note>
			<variablelist>
				<variable name="ALTSTREAM_WSSERVER">
					<para>The URL of the websocket server.</para>
				</variable>
			</variablelist>
			<warning><para>Do not use untrusted strings such as <variable>CALLERID(num)</variable>
			or <variable>CALLERID(name)</variable> as part of ANY of the application's
			parameters.  You risk a command injection attack executing arbitrary commands
			if the untrusted strings aren't filtered to remove dangerous characters.  See
			function <variable>FILTER()</variable>.</para></warning>
		</description>
		<see-also>
			<ref type="application">AltStream</ref>
			<ref type="application">StopAltStream</ref>
			<ref type="application">PauseMonitor</ref>
			<ref type="application">UnpauseMonitor</ref>
			<ref type="function">AUDIOHOOK_INHERIT</ref>
		</see-also>
	</application>
	<application name="StopAltStream" language="en_US">
		<synopsis>
			Cancels an ongoing audio fork and closes the websocket connection.
		</synopsis>
		<syntax>
			<parameter name="AltStreamID" required="false">
				<para>If a valid ID is provided, then this command will stop only that specific
				AltStream.</para>
			</parameter>
		</syntax>
		<description>
			<para>Stop an ongoing AltStream created previously by <literal>AltStream()</literal>
			on the current channel.</para>
		</description>
		<see-also>
			<ref type="application">AltStream</ref>
		</see-also>
	</application>
	<manager name="AltStreamMute" language="en_US">
		<synopsis>
			Mute / unMute a AltStream session.
		</synopsis>
		<syntax>
			<xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
			<parameter name="Channel" required="true">
				<para>Used to specify the channel to mute.</para>
			</parameter>
			<parameter name="Direction">
				<para>Which part of the audio fork to mute:  read, write or both (from channel, to channel or both channels).</para>
			</parameter>
			<parameter name="State">
				<para>Turn mute on or off : 1 to turn on, 0 to turn off.</para>
			</parameter>
		</syntax>
		<description>
			<para>This action may be used to mute a AltStream session.</para>
		</description>
	</manager>
	<manager name="AltStream" language="en_US">
		<synopsis>
			Forks a raw audio stream to a websocket server.
		</synopsis>
		<syntax>
			<xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
			<parameter name="Channel" required="true">
				<para>Used to specify the channel to record.</para>
			</parameter>
			<parameter name="WsServer">
				<para>The websocket server URL to fork audio to.</para>
			</parameter>
			<parameter name="options">
				<para>Options that apply to the AltStream in the same way as they
				would apply if invoked from the AltStream application. For a list of
				available options, see the documentation for the altstream application. </para>
			</parameter>
			<parameter name="Command">
				<para>Will be executed when the audio fork has completed.
				Any strings matching <literal>^{X}</literal> will be unescaped to <variable>X</variable>.
				All variables will be evaluated at the time AltStream is called.</para>
				<warning><para>Do not use untrusted strings such as <variable>CALLERID(num)</variable>
				or <variable>CALLERID(name)</variable> as part of the command parameters.  You
				risk a command injection attack executing arbitrary commands if the untrusted
				strings aren't filtered to remove dangerous characters.  See function
				<variable>FILTER()</variable>.</para></warning>
			</parameter>
		</syntax>
		<description>
			<para>This action will fork audio from an ongoing call to the designated websocket serrver.</para>
			<variablelist>
				<variable name="ALTSTREAM_WSSERVER">
					<para>The websocket server URL.</para>
				</variable>
			</variablelist>
		</description>
	</manager>
	<manager name="StopAltStream" language="en_US">
		<synopsis>
			Stops an ongoing AltStream() session
		</synopsis>
		<syntax>
			<xi:include xpointer="xpointer(/docs/manager[@name='Login']/syntax/parameter[@name='ActionID'])" />
			<parameter name="Channel" required="true">
				<para>The name of the channel monitored.</para>
			</parameter>
			<parameter name="AltStreamID" required="false">
				<para>If a valid ID is provided, then this command will stop only that specific
				AltStream.</para>
			</parameter>
		</syntax>
		<description>
			<para>This command stops the audio fork that was created by the <literal>AltStream</literal>
			action.</para>
		</description>
	</manager>
	<function name="ALTSTREAM" language="en_US">
		<synopsis>
			Retrieve data pertaining to specific instances of AltStream on a channel.
		</synopsis>
		<syntax>
			<parameter name="id" required="true">
				<para>The unique ID of the AltStream instance. The unique ID can be retrieved through the channel
				variable used as an argument to the <replaceable>i</replaceable> option to AltStream.</para>
			</parameter>
			<parameter name="key" required="true">
				<para>The piece of data to retrieve from the AltStream.</para>
				<enumlist>
					<enum name="filename" />
				</enumlist>
			</parameter>
		</syntax>
	</function>

 ***/

#define SAMPLES_PER_FRAME 160
#define get_volfactor(x) x ? ((x > 0) ? (1 << x) : ((1 << abs(x)) * -1)) : 0

static const char *const app = "AltStream";

static const char *const stop_app = "StopAltStream";

static const char *const altstream_spy_type = "AltStream";

struct altstream {
	struct ast_audiohook audiohook;
	struct ast_websocket *websocket;
	char *wsserver;
	struct ast_tls_config *tls_cfg;
	char *tcert;
	enum ast_audiohook_direction direction;
	const char *direction_string;
	int reconnection_attempts;
	int reconnection_timeout;
	char *post_process;
	char *name;
	ast_callid callid;
	unsigned int flags;
	struct ast_autochan *autochan;
	struct altstream_ds *altstream_ds;

	/* the below string fields describe data used for creating voicemails from the recording */
	 AST_DECLARE_STRING_FIELDS(
		AST_STRING_FIELD(call_context);
		AST_STRING_FIELD(call_macrocontext);
		AST_STRING_FIELD(call_extension);
		AST_STRING_FIELD(call_callerchan);
		AST_STRING_FIELD(call_callerid);
	);
	int call_priority;
	int has_tls;
};

enum altstream_flags {
	MUXFLAG_APPEND = (1 << 1),
	MUXFLAG_BRIDGED = (1 << 2),
	MUXFLAG_VOLUME = (1 << 3),
	MUXFLAG_READVOLUME = (1 << 4),
	MUXFLAG_WRITEVOLUME = (1 << 5),
	MUXFLAG_COMBINED = (1 << 8),
	MUXFLAG_UID = (1 << 9),
	MUXFLAG_BEEP = (1 << 11),
	MUXFLAG_BEEP_START = (1 << 12),
	MUXFLAG_BEEP_STOP = (1 << 13),
	MUXFLAG_RWSYNC = (1 << 14),
	MUXFLAG_DIRECTION = (1 << 15),
	MUXFLAG_TLS = (1 << 16),
	MUXFLAG_RECONNECTION_TIMEOUT = (1 << 17),
	MUXFLAG_RECONNECTION_ATTEMPTS = (1 << 17),
};

enum altstream_args {
	OPT_ARG_READVOLUME = 0,
	OPT_ARG_WRITEVOLUME,
	OPT_ARG_VOLUME,
	OPT_ARG_UID,
	OPT_ARG_BEEP_INTERVAL,
	OPT_ARG_RWSYNC,
	OPT_ARG_DIRECTION,
	OPT_ARG_TLS,
	OPT_ARG_RECONNECTION_TIMEOUT,
	OPT_ARG_RECONNECTION_ATTEMPTS,
	OPT_ARG_ARRAY_SIZE,           /* Always last element of the enum */
};

AST_APP_OPTIONS(altstream_opts, {
	AST_APP_OPTION('a', MUXFLAG_APPEND),
	AST_APP_OPTION('b', MUXFLAG_BRIDGED),
	AST_APP_OPTION_ARG('B', MUXFLAG_BEEP, OPT_ARG_BEEP_INTERVAL),
	AST_APP_OPTION('p', MUXFLAG_BEEP_START),
	AST_APP_OPTION('P', MUXFLAG_BEEP_STOP),
	AST_APP_OPTION_ARG('v', MUXFLAG_READVOLUME, OPT_ARG_READVOLUME),
	AST_APP_OPTION_ARG('V', MUXFLAG_WRITEVOLUME, OPT_ARG_WRITEVOLUME), 
	AST_APP_OPTION_ARG('W', MUXFLAG_VOLUME, OPT_ARG_VOLUME),
	AST_APP_OPTION_ARG('i', MUXFLAG_UID, OPT_ARG_UID),
	AST_APP_OPTION_ARG('S', MUXFLAG_RWSYNC, OPT_ARG_RWSYNC),
	AST_APP_OPTION_ARG('D', MUXFLAG_DIRECTION, OPT_ARG_DIRECTION),
	AST_APP_OPTION_ARG('T', MUXFLAG_TLS, OPT_ARG_TLS),
	AST_APP_OPTION_ARG('R', MUXFLAG_RECONNECTION_TIMEOUT, OPT_ARG_RECONNECTION_TIMEOUT),
	AST_APP_OPTION_ARG('r', MUXFLAG_RECONNECTION_ATTEMPTS, OPT_ARG_RECONNECTION_ATTEMPTS),
});

struct altstream_ds {
	unsigned int destruction_ok;
	ast_cond_t destruction_condition;
	ast_mutex_t lock;
	/**
	 * the audio hook we will use for sending raw audio
	 */
	struct ast_audiohook *audiohook;

	unsigned int samp_rate;
	char *wsserver;
	char *beep_id;
	struct ast_tls_config *tls_cfg;
};

static void altstream_ds_destroy(void *data)
{
	struct altstream_ds *altstream_ds = data;

	ast_mutex_lock(&altstream_ds->lock);
	altstream_ds->audiohook = NULL;
	altstream_ds->destruction_ok = 1;
	ast_free(altstream_ds->wsserver);
	ast_free(altstream_ds->beep_id);
	ast_cond_signal(&altstream_ds->destruction_condition);
	ast_mutex_unlock(&altstream_ds->lock);
}

static const struct ast_datastore_info altstream_ds_info = {
	.type = "altstream",
	.destroy = altstream_ds_destroy,
};

static void destroy_monitor_audiohook(struct altstream *altstream)
{
	if (altstream->altstream_ds) {
		ast_mutex_lock(&altstream->altstream_ds->lock);
		altstream->altstream_ds->audiohook = NULL;
		ast_mutex_unlock(&altstream->altstream_ds->lock);
	}
	/* kill the audiohook. */
	ast_audiohook_lock(&altstream->audiohook);
	ast_audiohook_detach(&altstream->audiohook);
	ast_audiohook_unlock(&altstream->audiohook);
	ast_audiohook_destroy(&altstream->audiohook);
}

static int start_altstream(struct ast_channel *chan, struct ast_audiohook *audiohook)
{
	if (!chan) {
		return -1;
	}

	return ast_audiohook_attach(chan, audiohook);
}

static int altstream_ws_close(struct altstream *altstream)
{
	int ret;
	ast_verb(2, "[AltStream] Closing websocket connection\n");
	if (altstream->websocket) {
		ast_verb(2, "[AltStream] Calling ast_websocket_close\n");
		ret = ast_websocket_close(altstream->websocket, 1011);
		return ret;
	}

	ast_verb(2, "[AltStream] No reference to websocket, can't close connection\n");
	return -1;
}


/*
	1 = success
	0 = fail
*/
static enum ast_websocket_result altstream_ws_connect(struct altstream *altstream)
{
	enum ast_websocket_result result;

	if (altstream->websocket) {
		ast_verb(2, "<%s> [AltStream] (%s) Reconnecting to websocket server at: %s\n",
			ast_channel_name(altstream->autochan->chan),
			altstream->direction_string,
			altstream->altstream_ds->wsserver);

		// close the websocket connection before reconnecting
		altstream_ws_close(altstream);

		ao2_cleanup(altstream->websocket);
	}
	else {
		ast_verb(2, "<%s> [AltStream] (%s) Connecting to websocket server at: %s\n",
			ast_channel_name(altstream->autochan->chan),
			altstream->direction_string,
			altstream->altstream_ds->wsserver);
	}

	// Check if we're running with TLS
	if (altstream->has_tls == 1) {
		ast_verb(2, "<%s> [AltStream] (%s) Creating to WebSocket server with TLS mode enabled\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
		altstream->websocket = ast_websocket_client_create(altstream->altstream_ds->wsserver, "echo", altstream->tls_cfg, &result);
	} else {
		ast_verb(2, "<%s> [AltStream] (%s) Creating to WebSocket server without TLS\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
		altstream->websocket = ast_websocket_client_create(altstream->altstream_ds->wsserver, "echo", NULL, &result);
	}

	return result;
}

/*
	reconn_status
	0 = OK
	1 = FAILED
*/
static int altstream_start_reconnecting(struct altstream *altstream)
{
	int counter= 0;
	int status = 0;
	int timeout = altstream->reconnection_timeout;
	int attempts = altstream->reconnection_attempts;
	int last_attempt = 0;
	int now;
	int delta;
	int result;

	while (counter < attempts) {
		now = (int)time(NULL);
		delta = now - last_attempt;

		// small check to see if we should keep waiting on the reconnection. This uses the
		// reconnection_timeout variable configured in the dialplan
		if (last_attempt != 0 && delta <= timeout) {
			// keep waiting
			continue;
		}

		// try to reconnect
		result = altstream_ws_connect(altstream);
		if (result == WS_OK) {
			status = 0;
			last_attempt = 0;
			break;
		}

		// reconnection failed...
		// update our counter with the last reconnection attempt
		last_attempt=(int)time(NULL);

		ast_log(LOG_ERROR, "<%s> [AltStream] (%s) Reconnection failed... trying again in %d seconds. %d attempts remaining reconn_now %d reconn_last_attempt %d\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string, timeout, (attempts-counter), now, last_attempt);

		counter ++;
		status = 1;
	}

	return status;
}

static void altstream_free(struct altstream *altstream)
{
	if (altstream) {
		if (altstream->altstream_ds) {
			ast_mutex_destroy(&altstream->altstream_ds->lock);
			ast_cond_destroy(&altstream->altstream_ds->destruction_condition);
			ast_free(altstream->altstream_ds);
		}

		ast_free(altstream->name);
		ast_free(altstream->post_process);
		ast_free(altstream->wsserver);

		altstream_ws_close(altstream);

		/* clean stringfields */
		ast_string_field_free_memory(altstream);

		ast_free(altstream);
	}
}



static void *altstream_thread(void *obj)
{
	struct altstream *altstream = obj;
	struct ast_format *format_slin;
	char *channel_name_cleanup;
	enum ast_websocket_result result;
	int frames_sent = 0;
	int reconn_status;

	/* Keep callid association before any log messages */
	if (altstream->callid) {
		ast_verb(2, "<%s> [AltStream] (%s) Keeping Call-ID Association\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
		ast_callid_threadassoc_add(altstream->callid);
	}

	result = altstream_ws_connect(altstream);
	if (result != WS_OK) {
		ast_log(LOG_ERROR, "<%s> Could not connect to websocket server: %s\n", ast_channel_name(altstream->autochan->chan), altstream->altstream_ds->wsserver);

		ast_test_suite_event_notify("ALTSTREAM_END", "Ws server: %s\r\n", altstream->wsserver);

		/* kill the audiohook */
		destroy_monitor_audiohook(altstream);
		ast_autochan_destroy(altstream->autochan);

		/* We specifically don't do altstream_free(altstream) here because the automatic datastore cleanup will get it */

		ast_module_unref(ast_module_info->self);

		return 0;
	}

	ast_verb(2, "<%s> [AltStream] (%s) Begin AltStream Recording %s\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string, altstream->name);

	//fs = &altstream->altstream_ds->fs;

	ast_mutex_lock(&altstream->altstream_ds->lock);
	format_slin = ast_format_cache_get_slin_by_rate(altstream->altstream_ds->samp_rate);

	ast_mutex_unlock(&altstream->altstream_ds->lock);

	/* The audiohook must enter and exit the loop locked */
	ast_audiohook_lock(&altstream->audiohook);

	while (altstream->audiohook.status == AST_AUDIOHOOK_STATUS_RUNNING) {
		// ast_verb(2, "<%s> [AltStream] (%s) Reading Audio Hook frame...\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
		struct ast_frame *fr = ast_audiohook_read_frame(&altstream->audiohook, SAMPLES_PER_FRAME, altstream->direction, format_slin);

		if (!fr) {
			ast_audiohook_trigger_wait(&altstream->audiohook);

			if (altstream->audiohook.status != AST_AUDIOHOOK_STATUS_RUNNING) {
				ast_verb(2, "<%s> [AltStream] (%s) AST_AUDIOHOOK_STATUS_RUNNING = 0\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
				break;
			}

			continue;
		}

		/* audiohook lock is not required for the next block.
		 * Unlock it, but remember to lock it before looping or exiting */
		ast_audiohook_unlock(&altstream->audiohook);
		struct ast_frame *cur;

		//ast_mutex_lock(&altstream->altstream_ds->lock);
		for (cur = fr; cur; cur = AST_LIST_NEXT(cur, frame_list)) {
			// ast_verb(2, "<%s> sending audio frame to websocket...\n", ast_channel_name(altstream->autochan->chan));
			// ast_mutex_lock(&altstream->altstream_ds->lock);

			if (ast_websocket_write(altstream->websocket, AST_WEBSOCKET_OPCODE_BINARY, cur->data.ptr, cur->datalen)) {

				ast_log(LOG_ERROR, "<%s> [AltStream] (%s) Could not write to websocket.  Reconnecting...\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
				reconn_status = altstream_start_reconnecting(altstream);

				if (reconn_status == 1) {
					altstream->websocket = NULL;
					altstream->audiohook.status = AST_AUDIOHOOK_STATUS_SHUTDOWN;
					break;
				}

				/* re-send the last frame */
				if (ast_websocket_write(altstream->websocket, AST_WEBSOCKET_OPCODE_BINARY, cur->data.ptr, cur->datalen)) {
					ast_log(LOG_ERROR, "<%s> [AltStream] (%s) Could not re-write to websocket.  Complete Failure.\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);

					altstream->audiohook.status = AST_AUDIOHOOK_STATUS_SHUTDOWN;
					break;
				}
			}

			frames_sent++;
		}

		//ast_mutex_unlock(&altstream->altstream_ds->lock);
		//

		/* All done! free it. */
		if (fr) {
			ast_frame_free(fr, 0);
		}

		fr = NULL;

		ast_audiohook_lock(&altstream->audiohook);
	}

	ast_audiohook_unlock(&altstream->audiohook);

	if (ast_test_flag(altstream, MUXFLAG_BEEP_STOP)) {
		ast_autochan_channel_lock(altstream->autochan);
		ast_stream_and_wait(altstream->autochan->chan, "beep", "");
		ast_autochan_channel_unlock(altstream->autochan);
	}

	channel_name_cleanup = ast_strdupa(ast_channel_name(altstream->autochan->chan));

	ast_autochan_destroy(altstream->autochan);

	/* Datastore cleanup.  close the filestream and wait for ds destruction */
	ast_mutex_lock(&altstream->altstream_ds->lock);
	if (!altstream->altstream_ds->destruction_ok) {
		ast_cond_wait(&altstream->altstream_ds->destruction_condition, &altstream->altstream_ds->lock);
	}
	ast_mutex_unlock(&altstream->altstream_ds->lock);

	/* kill the audiohook */
	destroy_monitor_audiohook(altstream);

	ast_verb(2, "<%s> [AltStream] (%s) Finished processing audiohook. Frames sent = %d\n", channel_name_cleanup, altstream->direction_string, frames_sent);
	ast_verb(2, "<%s> [AltStream] (%s) Post Process\n", channel_name_cleanup, altstream->direction_string);

	if (altstream->post_process) {
		ast_verb(2, "<%s> [AltStream] (%s) Executing [%s]\n", channel_name_cleanup, altstream->direction_string, altstream->post_process);
		ast_safe_system(altstream->post_process);
	}

	// altstream->name

	ast_verb(2, "<%s> [AltStream] (%s) End AltStream Recording to: %s\n", channel_name_cleanup, altstream->direction_string, altstream->wsserver);
	ast_test_suite_event_notify("ALTSTREAM_END", "Ws server: %s\r\n", altstream->wsserver);

	/* free any altstream memory */
	altstream_free(altstream);

	ast_module_unref(ast_module_info->self);

	return NULL;
}

static int setup_altstream_ds(struct altstream *altstream, struct ast_channel *chan, char **datastore_id, const char *beep_id)
{
	struct ast_datastore *datastore = NULL;
	struct altstream_ds *altstream_ds;

	if (!(altstream_ds = ast_calloc(1, sizeof(*altstream_ds)))) {
		return -1;
	}

	if (ast_asprintf(datastore_id, "%p", altstream_ds) == -1) {
		ast_log(LOG_ERROR, "Failed to allocate memory for AltStream ID.\n");
		ast_free(altstream_ds);
		return -1;
	}

	ast_mutex_init(&altstream_ds->lock);
	ast_cond_init(&altstream_ds->destruction_condition, NULL);

	if (!(datastore = ast_datastore_alloc(&altstream_ds_info, *datastore_id))) {
		ast_mutex_destroy(&altstream_ds->lock);
		ast_cond_destroy(&altstream_ds->destruction_condition);
		ast_free(altstream_ds);
		return -1;
	}

	if (ast_test_flag(altstream, MUXFLAG_BEEP_START)) {
		ast_autochan_channel_lock(altstream->autochan);
		ast_stream_and_wait(altstream->autochan->chan, "beep", "");
		ast_autochan_channel_unlock(altstream->autochan);
	}

	altstream_ds->samp_rate = 8000;
	altstream_ds->audiohook = &altstream->audiohook;
	altstream_ds->wsserver = ast_strdup(altstream->wsserver);
	if (!ast_strlen_zero(beep_id)) {
		altstream_ds->beep_id = ast_strdup(beep_id);
	}
	datastore->data = altstream_ds;

	ast_channel_lock(chan);
	ast_channel_datastore_add(chan, datastore);
	ast_channel_unlock(chan);

	altstream->altstream_ds = altstream_ds;
	return 0;
}

static int launch_altstream_thread(
	struct ast_channel *chan,
	const char *wsserver, unsigned int flags,
	enum ast_audiohook_direction direction,
	char* tcert,
	int reconn_timeout,
	int reconn_attempts,
	int readvol, int writevol,
	const char *post_process,
	const char *uid_channel_var,
	const char *beep_id
)
{
	pthread_t thread;
	struct altstream *altstream;
	char postprocess2[1024] = "";
	char *datastore_id = NULL;

	postprocess2[0] = 0;
	/* If a post process system command is given attach it to the structure */
	if (!ast_strlen_zero(post_process)) {
		char *p1, *p2;

		p1 = ast_strdupa(post_process);
		for (p2 = p1; *p2; p2++) {
			if (*p2 == '^' && *(p2 + 1) == '{') {
				*p2 = '$';
			}
		}
		ast_channel_lock(chan);
		pbx_substitute_variables_helper(chan, p1, postprocess2, sizeof(postprocess2) - 1);
		ast_channel_unlock(chan);
	}

	/* Pre-allocate altstream structure and spy */
	if (!(altstream = ast_calloc(1, sizeof(*altstream)))) {
		return -1;
	}

	/* Now that the struct has been calloced, go ahead and initialize the string fields. */
	if (ast_string_field_init(altstream, 512)) {
		altstream_free(altstream);
		return -1;
	}

	/* Setup the actual spy before creating our thread */
	if (ast_audiohook_init(&altstream->audiohook, AST_AUDIOHOOK_TYPE_SPY, altstream_spy_type, 0)) {
		altstream_free(altstream);
		return -1;
	}

	/* Copy over flags and channel name */
	altstream->flags = flags;
	if (!(altstream->autochan = ast_autochan_setup(chan))) {
		altstream_free(altstream);
		return -1;
	}

	/* Direction */
	altstream->direction = direction;

	if (direction == AST_AUDIOHOOK_DIRECTION_READ) {
		altstream->direction_string = "in";
	}
	else if (direction == AST_AUDIOHOOK_DIRECTION_WRITE) {
		altstream->direction_string = "out";
	}
	else {
		altstream->direction_string = "both";
	}

	ast_verb(2, "<%s> [AltStream] (%s) Setting Direction\n", ast_channel_name(chan), altstream->direction_string);

	// TODO: make this configurable
	altstream->reconnection_attempts = reconn_attempts;
	// 5 seconds
	altstream->reconnection_timeout = reconn_timeout;

	ast_verb(2, "<%s> [AltStream] Setting reconnection attempts to %d\n", ast_channel_name(chan), altstream->reconnection_attempts);
	ast_verb(2, "<%s> [AltStream] Setting reconnection timeout to %d\n", ast_channel_name(chan), altstream->reconnection_timeout);

	/* Server */
	if (!ast_strlen_zero(wsserver)) {
		ast_verb(2, "<%s> [AltStream] (%s) Setting wsserver: %s\n", ast_channel_name(chan), altstream->direction_string, wsserver);
		altstream->wsserver = ast_strdup(wsserver);
	}

	/* TLS */
	altstream->has_tls = 0;
	if (!ast_strlen_zero(tcert)) {
		ast_verb(2, "<%s> [AltStream] (%s) Setting TLS Cert: %s\n", ast_channel_name(chan), altstream->direction_string, tcert);
		struct ast_tls_config  *ast_tls_config;
		altstream->tls_cfg = ast_calloc(1, sizeof(*ast_tls_config));
		altstream->has_tls = 1;
		ast_set_flag(&altstream->tls_cfg->flags, AST_SSL_DONT_VERIFY_SERVER);
	}

	if (setup_altstream_ds(altstream, chan, &datastore_id, beep_id)) {
		ast_autochan_destroy(altstream->autochan);
		altstream_free(altstream);
		ast_free(datastore_id);
		return -1;
	}

	ast_verb(2, "<%s> [AltStream] (%s) Completed Setup\n", ast_channel_name(altstream->autochan->chan), altstream->direction_string);
	if (!ast_strlen_zero(uid_channel_var)) {
		if (datastore_id) {
			pbx_builtin_setvar_helper(chan, uid_channel_var, datastore_id);
		}
	}

	ast_free(datastore_id);
	altstream->name = ast_strdup(ast_channel_name(chan));

	if (!ast_strlen_zero(postprocess2)) {
		altstream->post_process = ast_strdup(postprocess2);
	}

	ast_set_flag(&altstream->audiohook, AST_AUDIOHOOK_TRIGGER_SYNC);
	if ((ast_test_flag(altstream, MUXFLAG_RWSYNC))) {
		ast_set_flag(&altstream->audiohook, AST_AUDIOHOOK_SUBSTITUTE_SILENCE);
	}

	if (readvol)
		altstream->audiohook.options.read_volume = readvol;
	if (writevol)
		altstream->audiohook.options.write_volume = writevol;

	if (start_altstream(chan, &altstream->audiohook)) {
		ast_log(LOG_WARNING, "<%s> (%s) [AltStream] Unable to add spy type '%s'\n", altstream->direction_string, ast_channel_name(chan), altstream_spy_type);
		ast_audiohook_destroy(&altstream->audiohook);
		altstream_free(altstream);
		return -1;
	}

	ast_verb(2, "<%s> [AltStream] (%s) Added AudioHook Spy\n", ast_channel_name(chan), altstream->direction_string);

	/* reference be released at altstream destruction */
	altstream->callid = ast_read_threadstorage_callid();

	return ast_pthread_create_detached_background(&thread, NULL, altstream_thread, altstream);
}

static int altstream_exec(struct ast_channel *chan, const char *data)
{
	int x, readvol = 0, writevol = 0;
	char *uid_channel_var = NULL;
	char beep_id[64] = "";
	unsigned int direction = 2;

	struct ast_flags flags = { 0 };
	char *parse;
	char *tcert = NULL;
	int reconn_timeout = 5;
	int reconn_attempts = 5;
	AST_DECLARE_APP_ARGS(args, 
		AST_APP_ARG(wsserver);
		AST_APP_ARG(options);
		AST_APP_ARG(post_process);
	);

	ast_log(LOG_NOTICE, "AltStream created with args %s\n", data);
	if (ast_strlen_zero(data)) {
		ast_log(LOG_WARNING, "AltStream requires an argument wsserver\n");
		return -1;
	}

	parse = ast_strdupa(data);

	AST_STANDARD_APP_ARGS(args, parse);

	if (args.options) {
		char *opts[OPT_ARG_ARRAY_SIZE] = { NULL, };

		ast_app_parse_options(altstream_opts, &flags, opts, args.options);

		if (ast_test_flag(&flags, MUXFLAG_READVOLUME)) {
			if (ast_strlen_zero(opts[OPT_ARG_READVOLUME])) {
				ast_log(LOG_WARNING, "No volume level was provided for the heard volume ('v') option.\n");
			} else if ((sscanf(opts[OPT_ARG_READVOLUME], "%2d", &x) != 1) || (x < -4) || (x > 4)) {
				ast_log(LOG_NOTICE, "Heard volume must be a number between -4 and 4, not '%s'\n", opts[OPT_ARG_READVOLUME]);
			} else {
				readvol = get_volfactor(x);
			}
		}

		if (ast_test_flag(&flags, MUXFLAG_WRITEVOLUME)) {
			if (ast_strlen_zero(opts[OPT_ARG_WRITEVOLUME])) {
				ast_log(LOG_WARNING, "No volume level was provided for the spoken volume ('V') option.\n");
			} else if ((sscanf(opts[OPT_ARG_WRITEVOLUME], "%2d", &x) != 1) || (x < -4) || (x > 4)) {
				ast_log(LOG_NOTICE, "Spoken volume must be a number between -4 and 4, not '%s'\n", opts[OPT_ARG_WRITEVOLUME]);
			} else {
				writevol = get_volfactor(x);
			}
		}

		if (ast_test_flag(&flags, MUXFLAG_VOLUME)) {
			if (ast_strlen_zero(opts[OPT_ARG_VOLUME])) {
				ast_log(LOG_WARNING, "No volume level was provided for the combined volume ('W') option.\n");
			} else if ((sscanf(opts[OPT_ARG_VOLUME], "%2d", &x) != 1) || (x < -4) || (x > 4)) {
				ast_log(LOG_NOTICE, "Combined volume must be a number between -4 and 4, not '%s'\n", opts[OPT_ARG_VOLUME]);
			} else {
				readvol = writevol = get_volfactor(x);
			}
		}

		if (ast_test_flag(&flags, MUXFLAG_UID)) {
			uid_channel_var = opts[OPT_ARG_UID];
		}

		if (ast_test_flag(&flags, MUXFLAG_BEEP)) {
			const char *interval_str = S_OR(opts[OPT_ARG_BEEP_INTERVAL], "15");
			unsigned int interval = 15;

			if (sscanf(interval_str, "%30u", &interval) != 1) {
				ast_log(LOG_WARNING, "Invalid interval '%s' for periodic beep. Using default of %u\n", interval_str, interval);
			}

			if (ast_beep_start(chan, interval, beep_id, sizeof(beep_id))) {
				ast_log(LOG_WARNING, "Unable to enable periodic beep, please ensure func_periodic_hook is loaded.\n");
				return -1;
			}
		}
		if (ast_test_flag(&flags, MUXFLAG_DIRECTION)) {
			const char *direction_str = opts[OPT_ARG_DIRECTION];

			if (!strcmp(direction_str, "in")) {
				direction = AST_AUDIOHOOK_DIRECTION_READ;
			} else if (!strcmp(direction_str, "out")) {
				direction = AST_AUDIOHOOK_DIRECTION_WRITE;
			} else if (!strcmp(direction_str, "both")) {
				direction = AST_AUDIOHOOK_DIRECTION_BOTH;
			} else {
				direction = AST_AUDIOHOOK_DIRECTION_BOTH;

				ast_log(LOG_WARNING, "Invalid direction '%s' given. Using default of 'both'\n", opts[OPT_ARG_DIRECTION]);
			}
		}

		if (ast_test_flag(&flags, MUXFLAG_TLS)) {
			tcert = ast_strdup ( S_OR(opts[OPT_ARG_TLS], "") );
			ast_verb(2, "Parsing TLS result tcert: %s\n", tcert);
		}

		if (ast_test_flag(&flags, MUXFLAG_RECONNECTION_TIMEOUT)) {
			reconn_timeout = atoi( S_OR(opts[OPT_ARG_RECONNECTION_TIMEOUT], "15") );
			ast_verb(2, "Reconnection timeout set to: %d\n", reconn_timeout);
		}

		if (ast_test_flag(&flags, MUXFLAG_RECONNECTION_ATTEMPTS)) {
			reconn_attempts = atoi( S_OR(opts[OPT_ARG_RECONNECTION_ATTEMPTS], "15") );
			ast_verb(2, "Reconnection attempts set to: %d\n", reconn_attempts);
		}
	}

	/* If there are no file writing arguments/options for the mix monitor, send a warning message and return -1 */

	if (ast_strlen_zero(args.wsserver)) {
		ast_log(LOG_WARNING, "AltStream requires an argument (wsserver)\n");
		return -1;
	}

	pbx_builtin_setvar_helper(chan, "ALTSTREAM_WSSERVER", args.wsserver);

	/* If launch_monitor_thread works, the module reference must not be released until it is finished. */
	ast_module_ref(ast_module_info->self);

	if (launch_altstream_thread(
		chan,
		args.wsserver,
		flags.flags,
		direction,
		tcert,
		reconn_timeout,
		reconn_attempts,
		readvol,
		writevol,
		args.post_process, 
		uid_channel_var, 
		beep_id)
	) {

		/* Failed */
		ast_module_unref(ast_module_info->self);
	}

	return 0;
}

static int stop_altstream_full(struct ast_channel *chan, const char *data)
{
	struct ast_datastore *datastore = NULL;
	char *parse = "";
	struct altstream_ds *altstream_ds;
	const char *beep_id = NULL;

	AST_DECLARE_APP_ARGS(args, AST_APP_ARG(altstreamid););

	if (!ast_strlen_zero(data)) {
		parse = ast_strdupa(data);
	}

	AST_STANDARD_APP_ARGS(args, parse);

	ast_channel_lock(chan);

	datastore = ast_channel_datastore_find(chan, &altstream_ds_info, S_OR(args.altstreamid, NULL));
	if (!datastore) {
		ast_channel_unlock(chan);
		return -1;
	}
	altstream_ds = datastore->data;

	ast_mutex_lock(&altstream_ds->lock);

	/* The altstream thread may be waiting on the audiohook trigger.
	 * In order to exit from the altstream loop before waiting on channel
	 * destruction, poke the audiohook trigger. */
	if (altstream_ds->audiohook) {
		if (altstream_ds->audiohook->status != AST_AUDIOHOOK_STATUS_DONE) {
			ast_audiohook_update_status(altstream_ds->audiohook, AST_AUDIOHOOK_STATUS_SHUTDOWN);
		}
		ast_audiohook_lock(altstream_ds->audiohook);
		ast_cond_signal(&altstream_ds->audiohook->trigger);
		ast_audiohook_unlock(altstream_ds->audiohook);
		altstream_ds->audiohook = NULL;
	}

	if (!ast_strlen_zero(altstream_ds->beep_id)) {
		beep_id = ast_strdupa(altstream_ds->beep_id);
	}

	ast_mutex_unlock(&altstream_ds->lock);

	/* Remove the datastore so the monitor thread can exit */
	if (!ast_channel_datastore_remove(chan, datastore)) {
		ast_datastore_free(datastore);
	}

	ast_channel_unlock(chan);

	if (!ast_strlen_zero(beep_id)) {
		ast_beep_stop(chan, beep_id);
	}

	return 0;
}

static int stop_altstream_exec(struct ast_channel *chan, const char *data)
{
	stop_altstream_full(chan, data);
	return 0;
}

static char *handle_cli_altstream(struct ast_cli_entry *e, int cmd, struct ast_cli_args *a)
{
	struct ast_channel *chan;
	struct ast_datastore *datastore = NULL;
	struct altstream_ds *altstream_ds = NULL;

	switch (cmd) {
		case CLI_INIT:
			e->command = "altstream {start|stop|list}";
			e->usage =
				"Usage: altstream start <chan_name> [args]\n"
				"         The optional arguments are passed to the AltStream application.\n"
				"       altstream stop <chan_name> [args]\n"
				"         The optional arguments are passed to the StopAltStream application.\n"
				"       altstream list <chan_name>\n";
			return NULL;
		case CLI_GENERATE:
			return ast_complete_channels(a->line, a->word, a->pos, a->n, 2);
	}

	if (a->argc < 3) {
		return CLI_SHOWUSAGE;
	}

	if (!(chan = ast_channel_get_by_name_prefix(a->argv[2], strlen(a->argv[2])))) {
		ast_cli(a->fd, "No channel matching '%s' found.\n", a->argv[2]);
		/* Technically this is a failure, but we don't want 2 errors printing out */
		return CLI_SUCCESS;
	}

	if (!strcasecmp(a->argv[1], "start")) {
		altstream_exec(chan, (a->argc >= 4) ? a->argv[3] : "");
	} else if (!strcasecmp(a->argv[1], "stop")) {
		stop_altstream_exec(chan, (a->argc >= 4) ? a->argv[3] : "");
	} else if (!strcasecmp(a->argv[1], "list")) {
		ast_cli(a->fd, "AltStream ID\tWs Server\tReceive File\tTransmit File\n");
		ast_cli(a->fd,
						"=========================================================================\n");
		ast_channel_lock(chan);
		AST_LIST_TRAVERSE(ast_channel_datastores(chan), datastore, entry) {
			if (datastore->info == &altstream_ds_info) {
				char *wsserver = "";
				char *filename_read = "";
				char *filename_write = "";

				altstream_ds = datastore->data;
				if (altstream_ds->wsserver) {
					wsserver = altstream_ds->wsserver;
				}
				ast_cli(a->fd, "%p\t%s\t%s\t%s\n", altstream_ds, wsserver,
								filename_read, filename_write);
			}
		}
		ast_channel_unlock(chan);
	} else {
		chan = ast_channel_unref(chan);
		return CLI_SHOWUSAGE;
	}

	chan = ast_channel_unref(chan);

	return CLI_SUCCESS;
}

/*! \brief  Mute / unmute  a MixMonitor channel */
static int manager_mute_altstream(struct mansession *s, const struct message *m)
{
	struct ast_channel *c;
	const char *name = astman_get_header(m, "Channel");
	const char *id = astman_get_header(m, "ActionID");
	const char *state = astman_get_header(m, "State");
	const char *direction = astman_get_header(m, "Direction");
	int clearmute = 1;
	enum ast_audiohook_flags flag;

	if (ast_strlen_zero(direction)) {
		astman_send_error(s, m, "No direction specified. Must be read, write or both");
		return AMI_SUCCESS;
	}

	if (!strcasecmp(direction, "read")) {
		flag = AST_AUDIOHOOK_MUTE_READ;
	} else if (!strcasecmp(direction, "write")) {
		flag = AST_AUDIOHOOK_MUTE_WRITE;
	} else if (!strcasecmp(direction, "both")) {
		flag = AST_AUDIOHOOK_MUTE_READ | AST_AUDIOHOOK_MUTE_WRITE;
	} else {
		astman_send_error(s, m, "Invalid direction specified. Must be read, write or both");
		return AMI_SUCCESS;
	}

	if (ast_strlen_zero(name)) {
		astman_send_error(s, m, "No channel specified");
		return AMI_SUCCESS;
	}

	if (ast_strlen_zero(state)) {
		astman_send_error(s, m, "No state specified");
		return AMI_SUCCESS;
	}

	clearmute = ast_false(state);

	c = ast_channel_get_by_name(name);
	if (!c) {
		astman_send_error(s, m, "No such channel");
		return AMI_SUCCESS;
	}

	if (ast_audiohook_set_mute(c, altstream_spy_type, flag, clearmute)) {
		ast_channel_unref(c);
		astman_send_error(s, m, "Cannot set mute flag");
		return AMI_SUCCESS;
	}

	astman_append(s, "Response: Success\r\n");

	if (!ast_strlen_zero(id)) {
		astman_append(s, "ActionID: %s\r\n", id);
	}

	astman_append(s, "\r\n");

	ast_channel_unref(c);

	return AMI_SUCCESS;
}

static int manager_altstream(struct mansession *s, const struct message *m)
{
	struct ast_channel *c;
	const char *name = astman_get_header(m, "Channel");
	const char *id = astman_get_header(m, "ActionID");
	const char *wsserver = astman_get_header(m, "WsServer");
	const char *options = astman_get_header(m, "Options");
	//const char *command = astman_get_header(m, "Command");
	char *opts[OPT_ARG_ARRAY_SIZE] = { NULL, };
	struct ast_flags flags = { 0 };
	char *uid_channel_var = NULL;
	const char *altstream_id = NULL;
	int res;
	char args[PATH_MAX];

	if (ast_strlen_zero(name)) {
		astman_send_error(s, m, "No channel specified");
		return AMI_SUCCESS;
	}

	c = ast_channel_get_by_name(name);
	if (!c) {
		astman_send_error(s, m, "No such channel");
		return AMI_SUCCESS;
	}

	if (!ast_strlen_zero(options)) {
		ast_app_parse_options(altstream_opts, &flags, opts, ast_strdupa(options));
	}

	snprintf(args, sizeof(args), "%s,%s", wsserver, options);

	res = altstream_exec(c, args);

	if (ast_test_flag(&flags, MUXFLAG_UID)) {
		uid_channel_var = opts[OPT_ARG_UID];
		ast_channel_lock(c);
		altstream_id = pbx_builtin_getvar_helper(c, uid_channel_var);
		altstream_id = ast_strdupa(S_OR(altstream_id, ""));
		ast_channel_unlock(c);
	}

	if (res) {
		ast_channel_unref(c);
		astman_send_error(s, m, "Could not start monitoring channel");
		return AMI_SUCCESS;
	}

	astman_append(s, "Response: Success\r\n");

	if (!ast_strlen_zero(id)) {
		astman_append(s, "ActionID: %s\r\n", id);
	}

	if (!ast_strlen_zero(altstream_id)) {
		astman_append(s, "AltStreamID: %s\r\n", altstream_id);
	}

	astman_append(s, "\r\n");

	ast_channel_unref(c);

	return AMI_SUCCESS;
}

static int manager_stop_altstream(struct mansession *s, const struct message *m)
{
	struct ast_channel *c;
	const char *name = astman_get_header(m, "Channel");
	const char *id = astman_get_header(m, "ActionID");
	const char *altstream_id = astman_get_header(m, "AltStreamID");
	int res;

	if (ast_strlen_zero(name)) {
		astman_send_error(s, m, "No channel specified");
		return AMI_SUCCESS;
	}

	c = ast_channel_get_by_name(name);
	if (!c) {
		astman_send_error(s, m, "No such channel");
		return AMI_SUCCESS;
	}

	res = stop_altstream_full(c, altstream_id);
	if (res) {
		ast_channel_unref(c);
		astman_send_error(s, m, "Could not stop monitoring channel");
		return AMI_SUCCESS;
	}

	astman_append(s, "Response: Success\r\n");

	if (!ast_strlen_zero(id)) {
		astman_append(s, "ActionID: %s\r\n", id);
	}

	astman_append(s, "\r\n");

	ast_channel_unref(c);

	return AMI_SUCCESS;
}

static int func_altstream_read(struct ast_channel *chan, const char *cmd, char *data, char *buf, size_t len)
{
	struct ast_datastore *datastore;
	struct altstream_ds *ds_data;
	AST_DECLARE_APP_ARGS(args, AST_APP_ARG(id); AST_APP_ARG(key););

	AST_STANDARD_APP_ARGS(args, data);

	if (ast_strlen_zero(args.id) || ast_strlen_zero(args.key)) {
		ast_log(LOG_WARNING, "Not enough arguments provided to %s. An ID and key must be provided\n", cmd);
		return -1;
	}

	ast_channel_lock(chan);
	datastore = ast_channel_datastore_find(chan, &altstream_ds_info, args.id);
	ast_channel_unlock(chan);

	if (!datastore) {
		ast_log(LOG_WARNING, "Could not find AltStream with ID %s\n", args.id);
		return -1;
	}

	ds_data = datastore->data;

	if (!strcasecmp(args.key, "filename")) {
		ast_copy_string(buf, ds_data->wsserver, len);
	} else {
		ast_log(LOG_WARNING, "Unrecognized %s option %s\n", cmd, args.key);
		return -1;
	}
	return 0;
}

static struct ast_custom_function altstream_function = {
	.name = "ALTSTREAM",
	.read = func_altstream_read,
};

static struct ast_cli_entry cli_altstream[] = {
	AST_CLI_DEFINE(handle_cli_altstream, "Execute a AltStream command")
};

static int set_altstream_methods(void)
{
	return 0;
}

static int clear_altstream_methods(void)
{
	return 0;
}

static int unload_module(void)
{
	int res;

	ast_cli_unregister_multiple(cli_altstream, ARRAY_LEN(cli_altstream));
	res = ast_unregister_application(stop_app);
	res |= ast_unregister_application(app);
	res |= ast_manager_unregister("AltStreamMute");
	res |= ast_manager_unregister("AltStream");
	res |= ast_manager_unregister("StopAltStream");
	res |= ast_custom_function_unregister(&altstream_function);
	res |= clear_altstream_methods();

	return res;
}

static int load_module(void)
{
	int res;

	ast_cli_register_multiple(cli_altstream, ARRAY_LEN(cli_altstream));
	res = ast_register_application_xml(app, altstream_exec);
	res |= ast_register_application_xml(stop_app, stop_altstream_exec);
	res |= ast_manager_register_xml("AltStreamMute", EVENT_FLAG_SYSTEM | EVENT_FLAG_CALL, manager_mute_altstream);
	res |= ast_manager_register_xml("AltStream", EVENT_FLAG_SYSTEM, manager_altstream);
	res |= ast_manager_register_xml("StopAltStream", EVENT_FLAG_SYSTEM | EVENT_FLAG_CALL, manager_stop_altstream);
	res |= ast_custom_function_register(&altstream_function);
	res |= set_altstream_methods();

	return res;
}

AST_MODULE_INFO(
	ASTERISK_GPL_KEY, 
	AST_MODFLAG_DEFAULT,
	"Audio Forking application",
	.support_level = AST_MODULE_SUPPORT_CORE,
	.load = load_module,
	.unload = unload_module,
	.optional_modules = "func_periodic_hook",
);
