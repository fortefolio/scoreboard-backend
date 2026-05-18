-- Function to trigger the edge function via pg_net
CREATE OR REPLACE FUNCTION public.handle_new_signup()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM
    net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/send-signup-email',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
      body := jsonb_build_object('record', row_to_json(NEW))
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute after a new participant is inserted
CREATE TRIGGER tr_send_signup_email
AFTER INSERT ON public.tournament_participants
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_signup();
