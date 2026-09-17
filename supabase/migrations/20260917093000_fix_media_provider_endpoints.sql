-- ShiftAI :: correct the media provider rows against the published API docs.
--
-- The previous migration seeded these from memory and got two wrong:
--   * Replicate moved from the custom "Token" scheme to standard Bearer.
--   * ElevenLabs exposes the account at /v1/user/subscription, not /v1/user.
-- The rest gain confirmed base URLs and verify endpoints.
--
-- All of these are submit-then-poll: a POST returns an id, and the caller polls
-- with a GET. chat_path stays null for them -- ai-proxy takes an explicit path
-- and method per call rather than pretending they are chat-shaped.

update public.ai_providers set
  auth_prefix = 'Bearer ',
  verify_path = '/v1/account'
where id = 'replicate';

update public.ai_providers set
  verify_path = '/v1/user/subscription'
where id = 'elevenlabs';

update public.ai_providers set
  verify_path = '/v2/user/remaining_quota'
where id = 'heygen';

-- fal.ai serves async work from queue.fal.run; submit to /{model-id}, then poll
-- /{model-id}/requests/{request_id}/status. No documented lightweight endpoint
-- for validating a key, so verification is skipped for this provider.
update public.ai_providers set
  base_url = 'https://queue.fal.run',
  verify_path = null
where id = 'fal';

-- BFL returns a polling_url on submit; always follow the returned URL rather
-- than rebuilding it. /v1/get_result?id=... is the documented shape.
update public.ai_providers set
  base_url = 'https://api.bfl.ai',
  verify_path = null
where id = 'flux';

update public.ai_providers set
  verify_path = '/v1/organization'
where id = 'runway';

-- Luma namespaces the whole API under /dream-machine/v1.
update public.ai_providers set
  base_url = 'https://api.lumalabs.ai',
  verify_path = null
where id = 'luma';
