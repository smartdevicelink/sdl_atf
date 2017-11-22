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

// SSL debug
#define SSL_WHERE_INFO(ssl, w, flag, msg) {                \
    if(w & flag) {                                         \
      printf("+ %s: ", name);                              \
      printf("%20.20s", msg);                              \
      printf(" - %40.40s ", SSL_state_string_long(ssl));   \
      printf(" - %5.10s ", SSL_state_string(ssl));         \
      printf("\n");                                        \
    }                                                      \
  }

typedef void(*info_callback)(const SSL*, int, int);

namespace {
	// C/C++ functions
	// debug
	void ssl_info_callback(const SSL* ssl, int where, int ret, const char* name) {

		if(ret == 0) {
			printf("-- ssl_info_callback: error occured.\n");
			return;
		}

		SSL_WHERE_INFO(ssl, where, SSL_CB_LOOP, "LOOP");
		SSL_WHERE_INFO(ssl, where, SSL_CB_HANDSHAKE_START, "HANDSHAKE START");
		SSL_WHERE_INFO(ssl, where, SSL_CB_HANDSHAKE_DONE, "HANDSHAKE DONE");
	}

	void ssl_server_info_callback(const SSL* ssl, int where, int ret) {
		ssl_info_callback(ssl, where, ret, "server");
	}

	void ssl_client_info_callback(const SSL* ssl, int where, int ret) {
		ssl_info_callback(ssl, where, ret, "client");
	}

	// implementation
	enum SecurityProtocols {
		SP_AUTO = 0,
		SP_SSL = 1,
		SP_TLS = 2,
		SP_DTLS = 3,
	};

	enum BIOTypes {
		BIO_SOURCE = 0,
		BIO_FILTER = 1
	};

	void initOpensslLib() {
		SSL_library_init();
		SSL_load_error_strings();
		ERR_load_BIO_strings();
		OpenSSL_add_all_algorithms();
	}

	int ssl_verify_peer(int ok, X509_STORE_CTX* ctx) {
		return 1;
	}

	void cleanupOpensslLib() {
		ERR_remove_state(0);
		ENGINE_cleanup();
		CONF_modules_unload(1);
		ERR_free_strings();
		EVP_cleanup();
		sk_SSL_COMP_free(SSL_COMP_get_compression_methods());
		CRYPTO_cleanup_all_ex_data();
	}

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
				return NULL;
		}

		SSL_CTX* ctx = SSL_CTX_new(method);
		if (!ctx) {
			printf("Error: cannot create SSL_CTX\n");
			ERR_print_errors_fp(stderr);
		}
		return ctx;
	}

	int setCipherListIntoSSLContext(SSL_CTX* ctx, const char* cipherListStr) {
		const int res = SSL_CTX_set_cipher_list(ctx, cipherListStr);
		if(res != 1) {
			printf("Error: cannot set the cipher list\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	int addCertificateIntoSSLContext(SSL_CTX* ctx, const char* certfile) {
		const int res = SSL_CTX_use_certificate_file(ctx, certfile, SSL_FILETYPE_PEM);
		if(res != 1) {
			printf("Error: cannot load certificate file\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	int addPrivateKeyIntoSSLContext(SSL_CTX* ctx, const char* keyfile) {
		const int res = SSL_CTX_use_PrivateKey_file(ctx, keyfile, SSL_FILETYPE_PEM);
		if(res != 1) {
			printf("Error: cannot load private key file\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	int checkPrivateKeyFromSSLContext(SSL_CTX* ctx) {
		const int res = SSL_CTX_check_private_key(ctx);
		if(res != 1) {
			printf("Error: checking the private key failed\n");
			ERR_print_errors_fp(stderr);
		}
		return res;
	}

	void setVerifyCallbackIntoSSLContext(SSL_CTX *ctx) {
		SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, ssl_verify_peer);
	}

	int initSSLContext(SSL_CTX* ctx, const char* cipherListStr,
						const char* certFile, const char* keyFile) {
		int res = 0;

		res = setCipherListIntoSSLContext(ctx, cipherListStr);
		if (res != 1) {
			return 0;
		}

		setVerifyCallbackIntoSSLContext(ctx);
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

		return 1;
	}

	void freeSSLContext(SSL_CTX* ctx) {
		SSL_CTX_free(ctx);
	}

	SSL* newSSL(SSL_CTX* ctx) {
		return SSL_new(ctx);
	}

	void freeSSL(SSL* ssl) {
		SSL_free(ssl); // implicitly frees linked BIOs
	}

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
				return NULL;
		}

		BIO* bio = BIO_new(methodType);
		if (bio && type == BIO_SOURCE) {
			BIO_set_mem_eof_return(bio, -1);
		}
		return bio;
	}

	void setInfoCallbackForSSL(SSL* ssl, info_callback cb) {
		SSL_set_info_callback(ssl, cb);
	}

	void setBIOSForSSL(SSL* ssl, BIO* bioIn, BIO* bioOut) {
		SSL_set_bio(ssl, bioIn, bioOut);
	}

	void prepareSSLToHandshake(SSL* ssl, const int isServer) {
		if (isServer == 1) {
			SSL_set_accept_state(ssl);
		}
		else {
			SSL_set_connect_state(ssl);
		}
	}

	int isHandshakeFinished(SSL* ssl) {
		return SSL_is_init_finished(ssl);
	}
	int doHandshake(SSL* ssl) {
		return SSL_do_handshake(ssl);
	}

	int getSSLErrorInfo(const SSL* ssl, const int returnOfSSLOperation) {
		return SSL_get_error(ssl, returnOfSSLOperation);
	}

	int readDecriptedDataFromSSL(SSL* ssl, char* buf, const int bufSize) {
		return SSL_read(ssl, buf, bufSize);
	}

	int checkDecriptedDataInSSL(SSL* ssl) {
		char buffer[1];
		readDecriptedDataFromSSL(ssl, buffer, 0);
		return SSL_pending(ssl);
	}

	int writeEncriptedDataIntoSSL(SSL* ssl, const char* buf, const int bufSize) {
		return SSL_write(ssl, buf, bufSize);
	}

	void printCertificatesInfoFromSSL(SSL* ssl) {
    	X509 *cert;
    	char *line;

    	cert = SSL_get_peer_certificate(ssl);
    	if ( cert != NULL )
    	{
        	printf("Certificates:\n");
        	line = X509_NAME_oneline(X509_get_subject_name(cert), 0, 0);
        	printf("Subject: %s\n", line);
        	free(line);
        	line = X509_NAME_oneline(X509_get_issuer_name(cert), 0, 0);
        	printf("Issuer: %s\n", line);
        	free(line);
        	X509_free(cert);
    	}
    	else
        printf("No certificates.\n");
	}

	int checkDataToReadInBIO(BIO* bio) {
		return BIO_ctrl_pending(bio);
	}

	int readDatafromBIO(BIO* bio, char* buf, const int bufSize) {
		return BIO_read(bio, buf, bufSize);
	}

	int writeDataIntoBIO(BIO* bio, const char* buf, const int bufSize) {
		return BIO_write(bio, buf, bufSize);
	}

	// Lua interfaces
	//OPENSSL
	int openssl_initSslLib(lua_State* L) {
		initOpensslLib();
		return 0;
	}

	int openssl_cleanupSslLib(lua_State* L) {
		cleanupOpensslLib();
		return 0;
	}

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

	int openssl_newBio(lua_State* L) {
		const int type = luaL_checknumber(L, 1);
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

	//SSL_CTX
	int ctx_initSslContext(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		const char* cipherListStr = luaL_checkstring(L, 2);
		const char* certFile = luaL_checkstring(L, 3);
		const char* keyFile = luaL_checkstring(L, 4);
		const int isSuccess = initSSLContext(ctx, cipherListStr, certFile, keyFile);
		lua_pushboolean(L, isSuccess);
		return 1;
	}

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

	int ctx_addCertificate(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		size_t size;
		const char* certfile = luaL_checklstring(L, 2, &size);
		addCertificateIntoSSLContext(ctx, certfile);
		return 0;
	}

	int ctx_free(lua_State* L) {
		SSL_CTX* ctx = *(SSL_CTX**)luaL_checkudata(L, 1, "openssl.ssl_ctx");
		freeSSLContext(ctx);
		return 0;
	}

	//SSL
	int ssl_setInfoCallback(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isServer = luaL_checknumber(L, 2);

		if (isServer == 1) {
			setInfoCallbackForSSL(ssl, ssl_server_info_callback);
		}
		else {
			setInfoCallbackForSSL(ssl, ssl_client_info_callback);
		}
		return 0;
	}

	int ssl_setBios(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		BIO* bioIn = *(BIO**)luaL_checkudata(L, 2, "openssl.bio");
		BIO* bioOut = *(BIO**)luaL_checkudata(L, 3, "openssl.bio");
		setBIOSForSSL(ssl, bioIn, bioOut);
		return 0;
	}

	int ssl_prepareToHandshake(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isServer = luaL_checknumber(L, 2);
		prepareSSLToHandshake(ssl, isServer);
		return 0;
	}

	int ssl_isHandshakeFinished(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int isFinished = isHandshakeFinished(ssl);
		lua_pushboolean(L, isFinished);
		return 1;
	}

	int ssl_performHandshake(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int result = doHandshake(ssl);
		const int info = getSSLErrorInfo(ssl, result);
		lua_pushinteger(L, result);
		lua_pushinteger(L, info);
		return 2;
	}

	int ssl_checkDataToDecript(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int dataSize = checkDecriptedDataInSSL(ssl);
		lua_pushinteger(L, dataSize);
		return 1;
	}

	int ssl_decrypt(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		const int size = luaL_checknumber(L, 2);
		char* buffer = new char[size];
		const int readSize = readDecriptedDataFromSSL(ssl, buffer, size);
		if (readSize <= 0) {
			delete[] buffer;
			return luaL_error(L, "Error occurred during data decription with Openssl SSL");
		}
		lua_pushlstring(L, buffer, readSize);
		delete[] buffer;
		return 1;
	}

	int ssl_encrypt(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		size_t size;
		const char* data = luaL_checklstring(L, 2, &size);
		const int writeSize = writeEncriptedDataIntoSSL(ssl, data, size);
		if (writeSize <= 0) {
			return luaL_error(L, "Error occurred during data encription with Openssl SSL");
		}
		return 0;
	}

	int ssl_printCertificatesInfo(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		printCertificatesInfoFromSSL(ssl);
		return 0;
	}


	int ssl_free(lua_State* L) {
		SSL* ssl = *(SSL**)luaL_checkudata(L, 1, "openssl.ssl");
		freeSSL(ssl);
		return 0;
	}

	//BIO
	int bio_checkDataToRead(lua_State* L) {
		BIO* bio = *(BIO**)luaL_checkudata(L, 1, "openssl.bio");
		const int datSize = checkDataToReadInBIO(bio);
		lua_pushinteger(L, datSize);
		return 1;
	}

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
int luaopen_luaopenssl(lua_State *L) {
	//SSL_CTX
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

	//SSL
	const luaL_Reg ssl_functions[] = {
		{ "setInfoCallback", &ssl_setInfoCallback },
		{ "setBios", &ssl_setBios },
		{ "prepareToHandshake", &ssl_prepareToHandshake },
		{ "performHandshake", &ssl_performHandshake },
		{ "isHandshakeFinished", &ssl_isHandshakeFinished },
		{ "printCertificatesInfo", &ssl_printCertificatesInfo },
		{ "checkData", &ssl_checkDataToDecript },
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

	//BIO
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

	//OPENSSL
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
