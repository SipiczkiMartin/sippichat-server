import 'package:sippichat_client/core/network/api_client.dart';
import 'package:sippichat_client/core/storage/token_storage.dart';
import 'package:sippichat_client/features/auth/auth_repository.dart';
import 'package:sippichat_client/features/chat/chat_controller.dart';
import 'package:sippichat_client/features/chat/chat_service.dart';
import 'package:sippichat_client/features/conversations/conversation_controller.dart';
import 'package:sippichat_client/features/conversations/conversation_service.dart';
import 'package:sippichat_client/features/profile/profile_service.dart';

import '../features/auth/auth_controller.dart';
import '../features/profile/profile_controller.dart';
import '../features/users/user_search_controller.dart';
import '../features/users/user_search_service.dart';

class AppDependencies {
  AppDependencies._();


  static final TokenStorage storage = TokenStorage();
  static final ApiClient apiClient = ApiClient(storage);
  static final AuthRepository authRepository = AuthRepository(apiClient: apiClient, storage: storage);
  static final AuthController authController = AuthController(authRepository);

  static final ConversationService conversationService = ConversationService(apiClient);
  static final ConversationController conversationController = ConversationController(conversationService);


  static final ChatService chatService = ChatService(apiClient);
  static final ChatController chatController = ChatController(chatService);

  static final ProfileService profileService = ProfileService(apiClient);
  static final ProfileController profileController = ProfileController(profileService);

  static final UserSearchService userSearchService = UserSearchService(apiClient);
  static final UserSearchController userSearchController = UserSearchController(userSearchService);


}