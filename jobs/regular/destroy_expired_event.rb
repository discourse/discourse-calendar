module Jobs
  class DestroyExpiredEvent < Jobs::Base
    def execute(args)
      post = Post.find(args[:post_id])

      if post
        op = post.topic.first_post
        DiscourseSimpleCalendar::EventDestroyer.destroy(op, post.post_number.to_s)
        PostDestroyer.new(Discourse.system_user, post).destroy
        op.publish_change_to_clients!(:calendar_change)
      end
    end
  end
end
