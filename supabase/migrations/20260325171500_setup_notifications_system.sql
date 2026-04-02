-- Create Notifications Table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Notifications RLS Policies
CREATE POLICY "Users can view their own notifications" 
ON public.notifications FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" 
ON public.notifications FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Trigger Function for Umpire Invitations
CREATE OR REPLACE FUNCTION public.handle_umpire_invitation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify if umpire_id is newly assigned or changed
    IF (TG_OP = 'INSERT' AND NEW.umpire_id IS NOT NULL) OR 
       (TG_OP = 'UPDATE' AND NEW.umpire_id IS NOT NULL AND (OLD.umpire_id IS NULL OR OLD.umpire_id <> NEW.umpire_id)) THEN
        
        INSERT INTO public.notifications (user_id, title, body, data)
        VALUES (
            NEW.umpire_id,
            'You have been invited to score a match!',
            'You are the umpire for the ' || NEW.sport_type || ' match.',
            jsonb_build_object(
                'match_id', NEW.id,
                'tournament_id', NEW.tournament_id,
                'type', 'umpire_invitation',
                'link', '/matches/' || NEW.id
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on Matches for Umpire Invitation
CREATE TRIGGER tr_notify_umpire_invitation
AFTER INSERT OR UPDATE ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_umpire_invitation();

-- Trigger Function for Match Completion Notifications to Followers
CREATE OR REPLACE FUNCTION public.handle_match_completion_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify when status changes to 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status <> 'completed') THEN
        
        -- Insert notifications for all followers of participants or the competition
        INSERT INTO public.notifications (user_id, title, body, data)
        SELECT 
            f.user_id,
            'Match Completed!',
            NEW.sport_type || ' match finished. Final Score: ' || NEW.current_score::TEXT,
            jsonb_build_object(
                'match_id', NEW.id,
                'tournament_id', NEW.tournament_id,
                'type', 'match_completed',
                'link', '/matches/' || NEW.id
            )
        FROM public.follows f
        WHERE 
            -- Following a participant (team/player) in the match
            (f.entity_type IN ('team', 'player') AND NEW.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
            OR
            -- Following the competition (tournament)
            (f.entity_type = 'competition' AND NEW.tournament_id = f.entity_id);
            
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for Match Completion
CREATE TRIGGER tr_notify_match_completion
AFTER UPDATE ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_match_completion_notification();
