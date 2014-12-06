#!/usr/bin/env roseus

(ros::load-ros-manifest "jsk_pepper_startup")
(ros::roseus "pepper_learning_sample")
(ros::roseus-add-msgs "nao_msgs")
(ros::roseus-add-srvs "nao_msgs")

;;topicのadvertise
(ros::advertise "/speech" std_msgs::String 1)
(ros::advertise "/regist_command" std_msgs::String 1)

;;speak
(defun speak-jp (str &rest args)
(let ((msg (instance std_msgs::String :init)))
(send msg :data (apply #'format nil str args))
(ros::ros-info "speech ~A" (send msg :data))
(ros::publish "/speech" msg))
)

;;speech recognition
(defun recognize-word (vocabulary &key (threshold 0.3) (wait 5))
  (let (tm req str)
    (setq str (car vocabulary))
    (dolist (v (cdr vocabulary))
      (setq str (format nil "~A / ~A" str v)))
    (setq req (instance dynamic_reconfigure::ReconfigureRequest :init))
    (send req :config :strs (list (instance dynamic_reconfigure::StrParameter :init :name "vocabulary" :value str)))
    (ros::ros-info "wait for nao_speech/set_parameters")
    (ros::wait-for-service "nao_speech/set_parameters")
    (ros::service-call "nao_speech/set_parameters" req)
    ;;
    (ros::ros-info "wait for start_recognition")
    (ros::wait-for-service "start_recognition")
    (call-empty-service "start_recognition")
    (setq *word-recognized* nil)
    (ros::subscribe "word_recognized" nao_msgs::WordRecognized
		    #'(lambda (msg)
			(ros::ros-info "Recognized ~A (~A)" (send msg :words) (send msg :confidence_values))
			(if (> (elt (send msg :confidence_values) 0) threshold)
			    (setq *word-recognized* (send msg :words)))))
    (setq tm (ros::time-now))
    (ros::rate 2)
    (while (and (< (send (ros::time- (ros::time-now) tm) :to-sec) wait)
		(null *word-recognized*))
      (ros::spin-once)
      (ros::ros-info "Recognizing.... ~A" str)
      (ros::sleep))
    (ros::unsubscribe "word_recognized")
    (ros::ros-info "wait for stop_recognition")
    (ros::wait-for-service "stop_recognition")
    (call-empty-service "stop_recognition")
    (car *word-recognized*)
    ))

;;learning
;;次にものの名前聞く　*mono* start_learn(*mono*)の流れにする
(defun start_learn ()
  (setq msg (instance std_msgs::string :init))
  (send msg :data  "ねこ")
  (ros::ros-info "~A" (send msg :data))
  (ros::publish "/regist_command" msg)
  )

;;main
(defun demo1 ()
  (let ((ret) (voc (list "覚えて")))
    (do-until-key
     (speak-jp "こんにちは")
     (setq ret (recognize-word voc :wait 15 :threshold 0.1))
     (unless ret
       (speak-jp "あれれ？")
       (setq ret (recognize-word voc :wait 10 :threshold 0.1)))
     (ros::ros-info "Recognized ~A~%" ret)
     (cond ((equal ret "覚えて")
	    (speak-jp "分かった")
	    (start_learn)
	    (speak-jp "覚えた")
	    ;;(setq msg (instance std_msgs::string :init))
	    ;;(send msg :data  "ねこ")
	    ;;(ros::ros-info "~A" (send msg :data))
	    ;;(ros::publish "regist_command" msg)
	    ;;(unix:sleep 10)
	    )
	   (t 
	    (speak-jp "もう一回言って？")
	    ;;(unix:sleep 10)
	    ))
     (unix:sleep 10)
     )
    )
  )
  
	  
(ros::ros-warn "usage")
(ros::ros-warn "say \"oboete\"")
(ros::ros-warn "(demo1)")