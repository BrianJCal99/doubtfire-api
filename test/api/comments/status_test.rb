require 'test_helper'

class StatusTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_status_comments
    project = Project.first
    user = project.student
    unit = project.unit

    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        abbreviation: 'test_status_comments',
        name: 'test_status_comments',
        description: 'test_status_comments',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.week,
        due_date: Time.zone.now + 1.day,
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    tutor = project.tutor_for(td)

    data_to_post = {
      trigger: 'ready_to_mark',
    }

    # Add auth_token and username to header
    add_auth_header_for(user: user)

    # Submit
    post_json "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["status"] == 'time_exceeded', "Error: Submission after deadline... should be time exceeded"

    task = Task.find(response['id'])

    assert_equal 2, task.comments.count

    rtm_comment = task.comments.where(task_status_id: TaskStatus.ready_to_mark.id).first
    te_comment = task.comments.where(task_status_id: TaskStatus.time_exceeded.id).first

    # Task status generated by students is marked read by staff
    assert rtm_comment.read_by?(user), 'Error: RTM status comment should be read by the student'
    assert rtm_comment.read_by?(tutor), 'Error: TE status comment should be read by the tutor'

    # Task status comments by staff is not marked read by students
    assert te_comment.read_by?(tutor), 'Error: TE status comment should be read by the tutor'
    assert te_comment.read_by?(user), 'Error: TE status comment should be read by the student'

    td.destroy!
  end

end
