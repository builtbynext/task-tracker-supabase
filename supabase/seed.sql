-- Sample actions, flagged so the app shows its "clear sample actions" banner.
-- Dates are relative to the day you run this, so the board always has a
-- believable mix of overdue, due-soon and completed items.

insert into public.meeting_actions (title, owner_name, due_on, meeting, done, done_on, agreed_on, is_sample) values
  ('Write up the incident timeline and circulate it', 'Dan Okafor',   current_date - 6, 'Post-incident review',   false, null,             current_date - 13, true),
  ('Send revised pricing sheet to Northgate',        'Priya Raman',   current_date - 2, 'Weekly commercial sync', false, null,             current_date - 9,  true),
  ('Chase the signed SOW from Halley Labs',          'Mei Tanaka',    current_date - 1, 'Weekly commercial sync', true,  current_date - 2, current_date - 9,  true),
  ('Confirm headcount budget with Finance',          'Priya Raman',   current_date + 1, 'Leadership monthly',     false, null,             current_date - 5,  true),
  ('Share the onboarding doc with the new starters', 'Dan Okafor',    current_date + 3, 'Weekly commercial sync', false, null,             current_date - 2,  true),
  ('Update the runbook for the new alerting rules',  'Sam Whitlock',  current_date + 5, 'Post-incident review',   false, null,             current_date - 13, true),
  ('Book the Q1 offsite venue',                      'Mei Tanaka',    current_date + 9, 'Leadership monthly',     false, null,             current_date - 5,  true),
  ('Circulate notes from the review',                'Sam Whitlock',  current_date - 4, 'Post-incident review',   true,  current_date - 5, current_date - 13, true);

-- To remove them later (the app's banner button does exactly this):
--   delete from public.meeting_actions where is_sample;
