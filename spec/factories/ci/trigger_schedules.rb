FactoryGirl.define do
  factory :ci_trigger_schedule, class: Ci::TriggerSchedule do
    project factory: :project
    trigger factory: :ci_trigger

    trait :force_triggable do
      after(:create) do |trigger_schedule, evaluator|
        trigger_schedule.next_run_at -= 1.month
      end
    end

    trait :cron_nightly_build do
      cron '0 1 * * *'
      cron_time_zone 'Europe/Istanbul'
      # next_run_at do # TODO: Use CronParser
      #   time = Time.now.in_time_zone(cron_time_zone)
      #   time = time + 1.day if time.hour > 1
      #   time = time.change(sec: 0, min: 0, hour: 1)
      #   time
      # end
    end

    trait :cron_weekly_build do
      cron '0 1 * * 5'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end

    trait :cron_monthly_build do
      cron '0 1 22 * *'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end

    trait :cron_every_5_minutes do
      cron '*/5 * * * *'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end

    trait :cron_every_5_hours do
      cron '* */5 * * *'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end

    trait :cron_every_5_days do
      cron '* * */5 * *'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end

    trait :cron_every_5_months do
      cron '* * * */5 *'
      cron_time_zone 'Europe/Istanbul'
      # TODO: next_run_at
    end
  end
end
