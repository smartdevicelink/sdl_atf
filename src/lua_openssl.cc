extern "C" {
#include <stdio.h>
#include <stdlib.h>

#include <lua5.2/lua.h>
#include <lua5.2/lualib.h>
#include <lua5.2/lauxlib.h>

#include <openssl/err.h>
#include <openssl/dh.h>
#include <openssl/ssl.h>
#include <openssl/conf.h>
#include <openssl/engine.h>
}

/**
* @brief Definition of function pointer type info_callback
* @param OpenSSL SSL
* @param OpenSSL SSL state machine status
* @param OpenSSL SSL return status
**/
typedef void(*info_callback)(const SSL*, int, int);

namespace {
	/**
	* @brief OpenSSL security protocols enumeration
	**/
	enum SecurityProtocols {
		SP_AUTO = 0,
		SP_SSL = 1,
		SP_TLS = 2,
		SP_DTLS = 3,
	};

	/**
	* @brief OpenSSL BIO types enumeration
	**/
	enum BIOTypes {
		BIO_SOURCE = 0,
		BIO_FILTER = 1
	};

	/**
	* @brief OpenSSL library initialization
	**/
	void initOpensslLib() {
		SSL_library_init();
		SSL_load_error_strings();
		ERR_load_BIO_strings();
		OpenSSL_add_all_algorithms();
	}

	/**
	* @brief OpenSSL library cleanup
	**/
	void cleanupOpensslLib() {
		ERR_remove_state(0);
		ENGINE_cleanup();
		CONF_modules_unload(1);
		ERR_free_strings();
		EVP_cleanup();
		sk_SSL_COMP_free(SSL_COMP_get_compression_methods());
		CRYPTO_cleanup_all_ex_data();
	}

	/**
	* @brief Create OpenSSL SSL_CTX with set security protocol
	* @param type Type of security protocol
	* @return OpenSSL SSL_CTX structure
	**/
	SSL_CTX* newSSLContext(const int type) {
		const SSL_METHOD* method;
		switch ((SecurityProtocols)type) {
			case SP_AUTO:
				method = SSLv23_method();
				break;
			case SP_TLS:
				method = TLSv1_2_method();
				break;
			case SP_SSL:
				method = SSLv3_method();
				break;
			case SP_DTLS:
				method = DTLSv1_method();
				break;
			default:
				printf("Error: Can not create SSL context with security protocol %d\n", type);
				return NULL;
		}

		SSL_CTX* ctx = SSL_CTX_new(method);
		if (!ctx) {
			printf("Error: cannot create SSL_CTX\n");
			ERR_print_errors_fp(stderr);
		}
		return ctx;
	}

	/**
	* @brief Set list of supported ciphers to OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @param cipherListStr List of supported ciphers
	* @return Set result. 1 - on success
	**/
	int setCipherListIntoSSLContext(SSL_CTX* ctx, const char* cipherListStr) {
		const int res = SSL_CTX_set_cipher_list(ctx, cipherListStr);
		if(res != 1) {
			printf("Error: cannot set the cipher list\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	/**
	* @brief Add security certificate from PEM file to OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @param certfile Path to PEM file with certificate
	* @return Addition result. 1 - on success
	**/
	int addCertificateIntoSSLContext(SSL_CTX* ctx, const char* certfile) {
		const int res = SSL_CTX_use_certificate_file(ctx, certfile, SSL_FILETYPE_PEM);
		if(res != 1) {
			printf("Error: cannot load certificate file\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	/**
	* @brief Add private key from PEM file to OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @param keyfile Path to PEM file with private key
	* @return Addition result. 1 - on success
	**/
	int addPrivateKeyIntoSSLContext(SSL_CTX* ctx, const char* keyfile) {
		const int res = SSL_CTX_use_PrivateKey_file(ctx, keyfile, SSL_FILETYPE_PEM);
		if(res != 1) {
			printf("Error: cannot load private key file\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	/**
	* @brief Check private key from OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @return Checking result. 1 - on success
	**/
	int checkPrivateKeyFromSSLContext(SSL_CTX* ctx) {
		const int res = SSL_CTX_check_private_key(ctx);
		if(res != 1) {
			printf("Error: checking the private key failed\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	/**
	* @brief Load chain of trusted CA certificates to OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @param CAfile Path to PEM file with chain of trusted CA certificates
	* @return Checking result. 1 - on success
	**/
	int loadTrustedCACertificates(SSL_CTX* ctx, const char* CAfile) {
		const int res = SSL_CTX_load_verify_locations(ctx, CAfile, NULL);
		if(res != 1) {
			printf("Error: loading of trusted CA certificates was failed\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	/**
	* @brief Callback function for peer verification
	* @return Certificate verification result
	**/
	int sslVerifyPeer(int isPreverifyOk, X509_STORE_CTX* ctx) {
		if (isPreverifyOk == 0) {
			X509* cert = X509_STORE_CTX_get_current_cert(ctx);
			int err = X509_STORE_CTX_get_error(ctx);
			int depth = X509_STORE_CTX_get_error_depth(ctx);
			char buf[256];
			X509_NAME_oneline(X509_get_subject_name(cert), buf, 256);
			printf("Certificate verification result: Error: \nnum = %d:%s\ndepth = %d:%s\n", err,
				X509_verify_cert_error_string(err), depth, buf);
		}

		return isPreverifyOk;
	}

	/**
	* @brief Set callback function for peer verification in OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	**/
	void setVerifyCallbackIntoSSLContext(SSL_CTX* ctx, int isCheckClientCertificate) {
		int mode = SSL_VERIFY_PEER;
		if (isCheckClientCertificate == 0) {
			mode = SSL_VERIFY_NONE;
		}

		SSL_CTX_set_verify(ctx, mode, sslVerifyPeer);
	}

	/**
	* @brief Initialize OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @param cipherListStr List of supported ciphers
	* @param certFile Path to PEM file with certificate
	* @param keyFile Path to PEM file with private key
	* @return Initialization result. 1 - on success
	**/
	int initSSLContext(SSL_CTX* ctx, const char* cipherListStr,
						const char* certFile, const char* keyFile,
						const int isCheckClientCertificate, const char* CAfile) {
		int res = setCipherListIntoSSLContext(ctx, cipherListStr);
		if (res != 1) {
			return 0;
		}

		res = addCertificateIntoSSLContext(ctx, certFile);
		if (res != 1) {
			return 0;
		}

		res = addPrivateKeyIntoSSLContext(ctx, keyFile);
		if (res != 1) {
			return 0;
		}

		res = checkPrivateKeyFromSSLContext(ctx);
		if (res != 1) {
			return 0;
		}

		if (isCheckClientCertificate == 1) {
			res = loadTrustedCACertificates(ctx, CAfile);
			if (res != 1) {
				return 0;
			}
		}

		setVerifyCallbackIntoSSLContext(ctx, isCheckClientCertificate);

		return 1;
	}

	/**
	* @brief Free memory allocated to OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	**/
	void freeSSLContext(SSL_CTX* ctx) {
		SSL_CTX_free(ctx);
	}

	/**
	* @brief Create OpenSSL SSL on base of OpenSSL SSL_CTX
	* @param ctx OpenSSL SSL_CTX
	* @return OpenSSL SSL structure
	**/
	SSL* newSSL(SSL_CTX* ctx) {
		return SSL_new(ctx);
	}

	/**
	* @brief Free memory allocated to OpenSSL SSL
	* @param ctx OpenSSL SSL
	**/
	void freeSSL(SSL* ssl) {
		SSL_free(ssl); // implicitly frees linked BIOs
	}

	/**
	* @brief Create OpenSSL BIO with set BIO type
	* @param type Type of BIO
	* @return OpenSSL BIO structure
	**/
	BIO* newBIO(const int type) {
		BIO_METHOD* methodType;
		switch ((BIOTypes)type) {
			case BIO_SOURCE:
				methodType = BIO_s_mem();
				break;
			case BIO_FILTER:
				methodType = BIO_f_ssl();
				break;
			default:
				printf("Error: Can not create BIO with type %d\n", type);
				return NULL;
		}

		BIO* bio = BIO_new(methodType);
		if (bio && type == BIO_SOURCE) {
			BIO_set_mem_eof_return(bio, -1);
		}
		return bio;
	}

	/**
	* @brief Print OpenSSL SSL status info
	* @param ssl OpenSSL SSL
	* @param where OpenSSL SSL state machine status
	* @param flag OpenSSL SSL state machine status mask
	* @param name Handshake role of current OpenSSL SSL
	* @param msg Message to print
	**/
	void sslInfo(const SSL* ssl, int where, int flag, const char* name, const char* msg) {
		if(where & flag) {
			printf("+ %s: ", name);
			printf("%20.20s", msg);
			printf(" - %40.40s ", SSL_state_string_long(ssl));
			printf(" - %5.10s ", SSL_state_string(ssl));
			printf("\n");
		}
	}

	/**
	* @brief SSL Info Callback
	* @param ssl OpenSSL SSL
	* @param where OpenSSL SSL state machine status
	* @param ret OpenSSL SSL return status
	* @param name Handshake role of current OpenSSL SSL
	**/
	void sslInfoCallback(const SSL* ssl, int where, int ret, const char* name) {
		if(ret == 0) {
			printf("-- SSL Info Callback: error occured.\n");
			return;
		}

		sslInfo(ssl, where, SSL_CB_LOOP, name, "LOOP");
		sslInfo(ssl, where, SSL_CB_HANDSHAKE_START, name, "HANDSHAKE START");
		sslInfo(ssl, where, SSL_CB_HANDSHAKE_DONE, name, "HANDSHAKE DONE");
	}

	/**
	* @brief SSL Info Callback for server
	* @param ssl OpenSSL SSL
	* @param where OpenSSL SSL state machine status
	* @param ret OpenSSL SSL return status
	**/
	void sslServerInfoCallback(const SSL* ssl, int where, int ret) {
		sslInfoCallback(ssl, where, ret, "server");
	}

	/**
	* @brief SSL Info Callback for client
	* @param ssl OpenSSL SSL
	* @param where OpenSSL SSL state machine status
	* @param ret OpenSSL SSL return status
	**/
	void sslClientInfoCallback(const SSL* ssl, int where, int ret) {
		sslInfoCallback(ssl, where, ret, "client");
	}

	/**
	* @brief Set SSL Info Callback for OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @param cb SSL Info Callback
	**/
	void setInfoCallbackForSSL(SSL* ssl, info_callback cb) {
		SSL_set_info_callback(ssl, cb);
	}

	/**
	* @brief Set input and output OpenSSL BIOs to OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @param bioIn OpenSSL BIO as input
	* @param bioOut OpenSSL BIO as output
	**/
	void setBIOSForSSL(SSL* ssl, BIO* bioIn, BIO* bioOut) {
		SSL_set_bio(ssl, bioIn, bioOut);
	}

	/**
	* @brief Prepare OpenSSL SSL according with its handshake role
	* @param ssl OpenSSL SSL
	* @param isServer handshake role. 1 - server, 0 - client
	**/
	void prepareSSLToHandshake(SSL* ssl, const int isServer) {
		if (isServer == 1) {
			SSL_set_accept_state(ssl);
		}
		else {
			SSL_set_connect_state(ssl);
		}
	}

	/**
	* @brief Check whether OpenSSL SSL handshake is finished
	* @param ssl OpenSSL SSL
	* @return Checking result. 1- Handshake is finished
	**/
	int isHandshakeFinished(SSL* ssl) {
		return SSL_is_init_finished(ssl);
	}

	/**
	* @brief Perform hendshake on base of OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @return Handshake result.
	**/
	int doHandshake(SSL* ssl) {
		return SSL_do_handshake(ssl);
	}

	/**
	* @brief Get error info for last operation with OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @param returnOfSSLOperation Result of last operation with OpenSSL SSL
	* @return Number of description of result last operation with OpenSSL SSL
	**/
	int getSSLErrorInfo(const SSL* ssl, const int returnOfSSLOperation) {
		return SSL_get_error(ssl, returnOfSSLOperation);
	}

	/**
	* @brief Read decrypted data from OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @param buf Buffer to store decrypted data
	* @param bufSize Size of buffer to store decrypted data
	* @return Reading data result
	**/
	int readDecryptedDataFromSSL(SSL* ssl, char* buf, const int bufSize) {
		return SSL_read(ssl, buf, bufSize);
	}

	/**
	* @brief Check of existence of decrypted data in OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @return Size of available decrypted data in OpenSSL SSL
	**/
	int checkDecryptedDataInSSL(SSL* ssl) {
		char buffer[1];
		readDecryptedDataFromSSL(ssl, buffer, 0);
		return SSL_pending(ssl);
	}

	/**
	* @brief Write and encrypt data to OpenSSL SSL
	* @param ssl OpenSSL SSL
	* @param buf Buffer with data
	* @param bufSize Size of buffer with data
	* @return Writing data result
	**/
	int writeEncryptedDataIntoSSL(SSL* ssl, const char* buf, const int bufSize) {
		return SSL_write(ssl, buf, bufSize);
	}

	/**
	* @brief Print certificates info from OpenSSL SSL
	* @param ssl OpenSSL SSL
	**/
	void printCertificatesInfoFromSSL(SSL* ssl) {
		X509* cert;
		char* line;

		cert = SSL_get_peer_certificate(ssl);
		if ( cert != NULL ) {
			printf("Certificates:\n");
			line = X509_NAME_oneline(X509_get_subject_name(cert), 0, 0);
			printf("Subject: %s\n", line);
			free(line);
			line = X509_NAME_oneline(X509_get_issuer_name(cert), 0, 0);
			printf("Issuer: %s\n", line);
			free(line);
			X509_free(cert);
		}
		else {
			printf("No certificates.\n");
		}
	}

	/**
	* @brief Check of existence of data to read in OpenSSL BIO
	* @param bio OpenSSL BIO
	* @return Size of available data in OpenSSL BIO
	**/
	int checkDataToReadInBIO(BIO* bio) {
		return BIO_ctrl_pending(bio);
	}

	/**
	* @brief Read data from OpenSSL BIO
	* @param bio OpenSSL BIO
	* @param buf Buffer for read data
	* @param bufSize Size of buffer for read data
	* @return Result of reading data from OpenSSL BIO
	**/
	int readDatafromBIO(BIO* bio, char* buf, const int bufSize) {
		return BIO_read(bio, buf, bufSize);
	}

	/**
	* @brief Write data into OpenSSL BIO
	* @param bio OpenSSL BIO
	* @param buf Buffer with data to write
	* @param bufSize Size of buffer with data to write
	* @return Result of writing data into OpenSSL BIO
	**/
	int writeDataIntoBIO(BIO* bio, const char* buf, const int bufSize) {
		return BIO_write(bio, buf, bufSize);
	}

	/**
	* @brief Lua openssl.main interface: OpenSSL library initialization
	* @param L Lua context state with stack: []
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int openssl_initSslLib(lua_State* L) {
		initOpensslLib();
		return 0;
	}

	/**
	* @brief Lua openssl.main interface: OpenSSL library cleanup
	* @param L Lua context state with stack: []
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int openssl_cleanupSslLib(lua_State* L) {
		cleanupOpensslLib();
		return 0;
	}

	/**
	* @brief Lua openssl.main interface: Create OpenSSL SSL_CTX with set security protocol
	* @param L Lua context state with stack:
	*	[
	*		type - Type of security protocol
	*	]
	* @return Count of results on top of Lua stack
	* 1 - userdata OpenSSL SSL_CTX structure
	**/
	int openssl_newSslContext(lua_State* L) {
		const int type = luaL_checknumber(L, 1);
		SSL_CTX* ctx = newSSLContext(type);
		if (ctx) {
			SSL_CTX** pCtx = (SSL_CTX**)lua_newuserdata(L, sizeof(SSL_CTX*));
			luaL_getmetatable(L, "openssl.ssl_ctx");
			lua_setmetatable(L, -2);
			*pCtx = ctx;
		}
		else {
			return luaL_error(L, "Cannot create SSL context with Openssl");
		}
		return 1;
	}

	/**
	* @brief Lua openssl.main interface: Create OpenSSL BIO with set BIO type
	* @param L Lua context state with stack:
	*	[
	*		type - Type of BIO
	*	]
	* @return Count of results on top of Lua stack
	* 1 - userdata OpenSSL BIO structure
	**/
	int openssl_newBio(lua_State* L) {
		const int type = luaL_checkinteger(L, 1);
		BIO* bio = newBIO(type);
		if(bio) {
			BIO** pBio = (BIO**)lua_newuserdata(L, sizeof(BIO*));
			luaL_getmetatable(L, "openssl.bio");
			lua_setmetatable(L, -2);
			*pBio = bio;
		}
		else {
			ERR_print_errors_fp(stderr);
			return luaL_error(L, "Cannot create BIO with Openssl");
		}
		return 1;
	}

	/**
	* @brief Lua openssl.ssl_ctx interface: Initialize OpenSSL SSL_CTX
	* @param L Lua context state with stack:
	*	[
	*		ctx - OpenSSL SSL_CTX
	*		cipherListStr - List of supported ciphers
	*		certFile - Path to PEM file with certificate
	*		keyFile - Path to PEM file with private key
	*		CAfile - Path to PEM file with chain of CA
	*			certificates for client certificate validation
	*		isCheckClientCertificate - True if client certificate
				needs to be validated
	*	]
	* @return Count of results on top of Lua stack
	* 1 - boolean Initialization result
	**/
	int ctx_initSslContext(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		const char* cipherListStr = luaL_checkstring(L, 2);
		const char* certFile = luaL_checkstring(L, 3);
		const char* keyFile = luaL_checkstring(L, 4);
		const char* CAfile = luaL_checkstring(L, 5);
		const int isCheckClientCertificate = lua_toboolean(L, 6);
		const int isSuccess = initSSLContext(ctx, cipherListStr, certFile,
								keyFile, isCheckClientCertificate, CAfile);
		lua_pushboolean(L, isSuccess);
		return 1;
	}

	/**
	* @brief Lua openssl.ssl_ctx interface: Create OpenSSL SSL on base of OpenSSL SSL_CTX
	* @param L Lua context state with stack:
	*	[
	*		ctx - OpenSSL SSL_CTX
	*	]
	* @return Count of results on top of Lua stack
	* 1 - userdata OpenSSL SSL structure
	**/
	int ctx_newSsl(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		SSL* ssl = newSSL(ctx);
		if(ssl) {
			SSL** pSsl = (SSL**)lua_newuserdata(L, sizeof(SSL*));
			luaL_getmetatable(L, "openssl.ssl");
			lua_setmetatable(L, -2);
			*pSsl = ssl;
		}
		else {
			ERR_print_errors_fp(stderr);
			return luaL_error(L, "Cannot create SSL with Openssl");
		}
		return 1;
	}

	/**
	* @brief Lua openssl.ssl_ctx interface: Add security certificate from PEM file to OpenSSL SSL_CTX
	* @param L Lua context state with stack:
	*	[
	*		ctx - OpenSSL SSL_CTX
	*		certfile - Path to PEM file with certificate
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ctx_addCertificate(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		size_t size;
		const char* certfile = luaL_checklstring(L, 2, &size);
		addCertificateIntoSSLContext(ctx, certfile);
		return 0;
	}

	/**
	* @brief Lua openssl.ssl_ctx interface: Free memory allocated to OpenSSL SSL_CTX
	* @param L Lua context state with stack:
	*	[
	*		ctx - OpenSSL SSL_CTX
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ctx_free(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		freeSSLContext(ctx);
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Set SSL Info Callback for OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*		isServer - Handshake role of current OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_setInfoCallback(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isServer = luaL_checknumber(L, 2);

		if (isServer == 1) {
			setInfoCallbackForSSL(ssl, sslServerInfoCallback);
		}
		else {
			setInfoCallbackForSSL(ssl, sslClientInfoCallback);
		}
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Set input and output OpenSSL BIOs to OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*		bioIn - OpenSSL BIO as input
	*		bioOut - OpenSSL BIO as output
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_setBios(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		BIO* bioIn = *(BIO**)luaL_checkudata(L, 2, "openssl.bio");
		BIO* bioOut = *(BIO**)luaL_checkudata(L, 3, "openssl.bio");
		setBIOSForSSL(ssl, bioIn, bioOut);
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Prepare OpenSSL SSL according with its handshake role
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*		isServer - Handshake role of current OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_prepareToHandshake(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isServer = luaL_checknumber(L, 2);
		prepareSSLToHandshake(ssl, isServer);
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Check whether OpenSSL SSL handshake is finished
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 1 - boolean Is SSL handshake finished
	**/
	int ssl_isHandshakeFinished(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isFinished = isHandshakeFinished(ssl);
		lua_pushboolean(L, isFinished);
		return 1;
	}

	/**
	* @brief Lua openssl.ssl interface: Perform hendshake on base of OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 1 - number Handshake result
	* 2 - number Number of description of Handshake result
	**/
	int ssl_performHandshake(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int result = doHandshake(ssl);
		const int info = getSSLErrorInfo(ssl, result);
		lua_pushinteger(L, result);
		lua_pushinteger(L, info);
		return 2;
	}

	/**
	* @brief Lua openssl.ssl interface: Check of existence of decrypted data in OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 1 - number Size of available decrypted data in OpenSSL SSL
	**/
	int ssl_checkDataToDecrypt(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int dataSize = checkDecryptedDataInSSL(ssl);
		lua_pushinteger(L, dataSize);
		return 1;
	}

	/**
	* @brief Lua openssl.ssl interface: Read decrypted data from OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*		size - Size of buffer to store decrypted data
	*	]
	* @return Count of results on top of Lua stack
	* 1 - string Read decrypted data
	**/
	int ssl_decrypt(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int size = luaL_checknumber(L, 2);
		char* buffer = new char[size];
		const int readSize = readDecryptedDataFromSSL(ssl, buffer, size);
		if (readSize <= 0) {
			delete[] buffer;
			return luaL_error(L, "Error occurred during data decryption with Openssl SSL");
		}
		lua_pushlstring(L, buffer, readSize);
		delete[] buffer;
		return 1;
	}

	/**
	* @brief Lua openssl.ssl interface: Write and encrypt data to OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*		data - Raw data
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_encrypt(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		size_t size;
		const char* data = luaL_checklstring(L, 2, &size);
		const int writeSize = writeEncryptedDataIntoSSL(ssl, data, size);
		if (writeSize <= 0) {
			return luaL_error(L, "Error occurred during data encryption with Openssl SSL");
		}
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Print certificates info from OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_printCertificatesInfo(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		printCertificatesInfoFromSSL(ssl);
		return 0;
	}

	/**
	* @brief Lua openssl.ssl interface: Free memory allocated to OpenSSL SSL
	* @param L Lua context state with stack:
	*	[
	*		ssl - OpenSSL SSL
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int ssl_free(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		freeSSL(ssl);
		return 0;
	}

	/**
	* @brief Lua openssl.bio interface: Check of existence of data to read in OpenSSL BIO
	* @param L Lua context state with stack:
	*	[
	*		bio - OpenSSL BIO
	*	]
	* @return Count of results on top of Lua stack
	* 1 - number Size of available data in OpenSSL BIO
	**/
	int bio_checkDataToRead(lua_State* L) {
		BIO* bio = *(BIO**)luaL_checkudata(L, 1, "openssl.bio");
		const int datSize = checkDataToReadInBIO(bio);
		lua_pushinteger(L, datSize);
		return 1;
	}

	/**
	* @brief Lua openssl.bio interface: Read data from OpenSSL BIO
	* @param L Lua context state with stack:
	*	[
	*		bio - OpenSSL BIO
	*		size - Size of buffer to store data
	*	]
	* @return Count of results on top of Lua stack
	* 1 - string Read data
	**/
	int bio_readData(lua_State* L) {
		BIO* bio = *(BIO**)luaL_checkudata(L, 1, "openssl.bio");
		const int size = luaL_checknumber(L, 2);
		char* buffer = new char[size];
		const int readSize = readDatafromBIO(bio, buffer, size);
		if (readSize < 0) {
			delete[] buffer;
			return luaL_error(L, "Error occurred during reading data from Openssl BIO");
		}
		lua_pushlstring(L, buffer, readSize);
		delete[] buffer;
		return 1;
	}

	/**
	* @brief Lua openssl.bio interface: Write data into OpenSSL BIO
	* @param L Lua context state with stack:
	*	[
	*		bio - OpenSSL BIO
	*		data - Data to write
	*	]
	* @return Count of results on top of Lua stack
	* 0 - void
	**/
	int bio_writeData(lua_State* L) {
		BIO* bio = *(BIO**)luaL_checkudata(L, 1, "openssl.bio");
		size_t size;
		const char* data = luaL_checklstring(L, 2, &size);
		int writeSize = writeDataIntoBIO(bio, data, size);
		if (writeSize < 0) {
			return luaL_error(L, "Error occurred during writing data to Openssl BIO");
		}
		return 0;
	}
}

extern "C"

/**
* @brief Create C library for Lua
* @param L Lua context state with stack: []
* @return Count of results on top of Lua stack
* 1 - table Representation C functions in Lua
**/
int luaopen_luaopenssl(lua_State *L) {
	const luaL_Reg ctx_functions[] = {
		{ "initSslContext", &ctx_initSslContext },
		{ "newSsl", &ctx_newSsl },
		{ "addCertificate", &ctx_addCertificate },
		{ NULL, NULL }
	};

	luaL_newmetatable(L, "openssl.ssl_ctx");
	lua_newtable(L);
	luaL_setfuncs(L, ctx_functions, 0);
	lua_setfield(L, -2, "__index");
	lua_pushcfunction(L, ctx_free);
	lua_setfield(L, -2, "__gc");

	const luaL_Reg ssl_functions[] = {
		{ "setInfoCallback", &ssl_setInfoCallback },
		{ "setBios", &ssl_setBios },
		{ "prepareToHandshake", &ssl_prepareToHandshake },
		{ "performHandshake", &ssl_performHandshake },
		{ "isHandshakeFinished", &ssl_isHandshakeFinished },
		{ "printCertificatesInfo", &ssl_printCertificatesInfo },
		{ "checkData", &ssl_checkDataToDecrypt },
		{ "decrypt", &ssl_decrypt },
		{ "encrypt", &ssl_encrypt },
		{ NULL, NULL }
	};

	luaL_newmetatable(L, "openssl.ssl");
	lua_newtable(L);
	luaL_setfuncs(L, ssl_functions, 0);
	lua_setfield(L, -2, "__index");
	lua_pushcfunction(L, ssl_free);
	lua_setfield(L, -2, "__gc");

	const luaL_Reg bio_functions[] = {
		{ "checkData", &bio_checkDataToRead },
		{ "read", &bio_readData },
		{ "write", &bio_writeData },
		{ NULL, NULL }
	};

	luaL_newmetatable(L, "openssl.bio");
	lua_newtable(L);
	luaL_setfuncs(L, bio_functions, 0);
	lua_setfield(L, -2, "__index");

	const luaL_Reg openssl_functions[] = {
		{ "initSslLibrary", &openssl_initSslLib },
		{ "newSslContext", &openssl_newSslContext },
		{ "newBio", &openssl_newBio },
		{ NULL, NULL }
	};

	luaL_newlib(L, openssl_functions);

	luaL_newmetatable(L, "openssl.main");
	lua_pushcfunction(L, openssl_cleanupSslLib);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);

	return 1;
}
